class AiDecisionJob < ApplicationJob
  include AiRouterConcern
  include Interruptible

  queue_as :default

  # The in-method rescue already released the lock; on exhaustion keep the
  # decision loop alive instead of letting the conversation go silent.
  # Restart, not continue: extract_job_args can't carry the Integer
  # generation (it only extracts a trailing options Hash), and a fresh bump
  # is correct here anyway — the failed link WAS the current line.
  ai_pipeline_retry do |conversation_id, _options|
    AiDecisionJob.restart_chain(conversation_id, jitter: true)
  end

  def perform(conversation_id, chain_gen = nil)
    gen_key = self.class.generation_key(conversation_id)
    # Pre-generation enqueues (deploy transition) adopt a fresh generation,
    # superseding whatever they may have forked from
    chain_gen ||= DistributedLockManager.bump_generation(gen_key)
    # Chain-fork guard: every restart bumps the generation, so a link
    # enqueued before the restart fires with a stale one — a superseded
    # chain that must die here instead of rescheduling itself. Without
    # this, each user message forks a second self-perpetuating loop that
    # hour-long idle waits would never merge back (short waits used to
    # merge forks via lock-contention skips within the hour).
    unless chain_gen == DistributedLockManager.current_generation(gen_key)
      Rails.logger.info "AiDecisionJob: superseded chain link for conversation #{conversation_id}, dropping"
      return
    end

    # Every run — including busy skips — proves the chain alive (gap between
    # runs is bounded by max wait + jitter, far inside HEARTBEAT_TTL)
    self.class.stamp_heartbeat(conversation_id)

    conversation = Conversation.find(conversation_id)
    return unless conversation.active?

    lock_key = DistributedLockManager.ai_decision_key(conversation_id)
    lock_token = DistributedLockManager.acquire(lock_key)

    unless lock_token
      # This link is the current generation's sole successor (stale links
      # died at the guard above), so it must retry rather than die: the
      # lock holder's own successor may be stale by now. Bounded against
      # ghost locks by the lock TTL — a few jittered cycles, then acquires.
      Rails.logger.info "AiDecisionJob busy for conversation #{conversation_id}, rescheduling"
      AiDecisionJob.schedule_with_jitter(conversation_id, chain_gen)
      return
    end

    decider = Ai::ActionDecider.new(router: ai_router)

    result = run_interruptible(conversation, lock_key, lock_token, 'AI decision') do
      decider.decide_action(conversation)
    end
    return if result[:interrupted]

    decision = result[:value]

    Rails.logger.info "AI decision for conversation #{conversation_id}: #{decision[:action]}"

    case decision[:action]
    when 'respond', 'initiate'
      AiMessageGenerationJob.perform_later(conversation_id, action: decision[:action], lock_token: lock_token)
      lock_token = nil
    when 'read_only'
      result = interruptible_thinking_pause(conversation, lock_key, lock_token, 'thinking_before_read_only', 'reading')
      return if result[:interrupted]

      # A non-interrupted pause proves nothing arrived since it began, so
      # its started_at bounds the mark to messages the decision considered
      mark_messages_as_read(conversation, before: result[:started_at])
      DistributedLockManager.release(lock_key, lock_token)
      AiDecisionJob.continue_chain(conversation_id, chain_gen)
    when 'wait'
      DistributedLockManager.release(lock_key, lock_token)
      wait_seconds = decision[:wait_seconds].to_i
      if AiDecisionJob.continue_chain(conversation_id, chain_gen, wait: wait_seconds.seconds)
        # A parked link can outlive the default heartbeat, so re-stamp sized
        # to the wait — AFTER the enqueue (a crash between the two leaves a
        # short stamp on a live successor: benign supersede-revival). The
        # swallow is load-bearing: a raise here would retry this link into a
        # same-generation fork beside its already-parked successor.
        begin
          self.class.stamp_heartbeat(conversation_id, ttl: wait_seconds + HEARTBEAT_MARGIN)
        rescue StandardError => e
          Rails.logger.error "AiDecisionJob: wait heartbeat re-stamp failed: #{e.message}"
        end
      end
    else
      # An unrecognized model action must not strand the lock or break the chain
      Rails.logger.warn "AiDecisionJob: unrecognized action #{decision[:action].inspect} for conversation #{conversation_id}, rescheduling"
      DistributedLockManager.release(lock_key, lock_token)
      AiDecisionJob.continue_chain(conversation_id, chain_gen)
    end
  rescue StandardError => e
    # Release so the retry can re-acquire. lock_token is nilled after each
    # handoff, so this can't release a token generation owns — except the
    # push-then-raise window, contained by FragmentSendJob's ownership
    # refresh. If the release itself fails, the successor link retries past
    # the ghost lock once its TTL expires (see the busy-skip reschedule).
    DistributedLockManager.release(lock_key, lock_token)
    Rails.logger.error "AiDecisionJob failed: #{e.message}, released lock for retry"
    raise
  end

  # Continuation of an already-live chain — callers outside a running link
  # must use restart_chain instead (a nil generation self-adopts on arrival)
  def self.schedule_with_jitter(conversation_id, chain_gen)
    set(wait: rand(AppConstants::AI_DECISION_MIN_DELAY..AppConstants::AI_DECISION_MAX_DELAY).seconds)
      .perform_later(conversation_id, chain_gen)
  end

  # Chain continuation for a link that ran to a non-handoff outcome:
  # advance the generation iff still ours, so any duplicate of this link
  # (ambiguous enqueue, shutdown re-push) dies at the guard instead of
  # forking a parallel same-generation chain. Returns false when an
  # external restart superseded this run mid-flight — the restart's link
  # owns the chain and no successor may be enqueued. A duplicate can still
  # run one full decision before its own advance fails; guard-passing
  # execution is at-least-once, not exactly-once (accepted).
  def self.continue_chain(conversation_id, chain_gen, wait: nil)
    next_gen = DistributedLockManager.advance_generation(generation_key(conversation_id), chain_gen)
    return false if next_gen == -1

    begin
      if wait
        set(wait: wait).perform_later(conversation_id, next_gen)
      else
        schedule_with_jitter(conversation_id, next_gen)
      end
    rescue StandardError
      # The advance already condemned every older link; a lost enqueue here
      # would strand the chain, so fall back to a full restart (best-effort,
      # never raises) before surfacing the original error
      restart_chain(conversation_id, jitter: true)
      raise
    end
    true
  end

  # THE external entry point: any new reason to reconsider now (user
  # message, interrupt, post-response bookkeeping, revival) supersedes every
  # parked link — bump the generation, then enqueue the sole live successor.
  # Best-effort end-to-end: no caller can act on a failed restart (fire-and-
  # forget sites, controllers post-commit), and raising after the bump would
  # leave every parked link superseded with no successor.
  def self.restart_chain(conversation_id, jitter: false)
    chain_gen = DistributedLockManager.bump_generation(generation_key(conversation_id))
    # The bump just superseded any parked wait whose long stamp could
    # outlive a failed enqueue below — shorten to the default TTL so a
    # fully-failed restart is revivable in TTL + sweep (the restarted link
    # re-stamps on arrival). Own rescue: a stamp failure must not divert
    # into the enqueue fallback.
    begin
      stamp_heartbeat(conversation_id)
    rescue StandardError => e
      Rails.logger.error "AiDecisionJob: restart heartbeat re-stamp failed: #{e.message}"
    end
    if jitter
      schedule_with_jitter(conversation_id, chain_gen)
    else
      perform_later(conversation_id, chain_gen)
    end
  rescue StandardError => e
    Rails.logger.error "AiDecisionJob: chain restart failed for conversation #{conversation_id} (#{e.message}), attempting generation-less fallback"
    # nil self-adopts by bumping on arrival, preserving supersede semantics
    # if this enqueue lands; a second failure leaves recovery to revive_all
    begin
      perform_later(conversation_id)
    rescue StandardError => e2
      Rails.logger.error "AiDecisionJob: fallback enqueue also failed for conversation #{conversation_id}: #{e2.message}"
      nil
    end
  end

  def self.generation_key(conversation_id)
    "decision_chain_gen:#{conversation_id}"
  end

  # Liveness heartbeat for the self-chaining decision loop. The default TTL
  # covers every short gap — jittered links (≤2min), generation/fragment
  # handoff flows, queue latency — so killed flows are revivable within one
  # TTL + sweep. Wait-parked links outlive it by design: the wait branch
  # re-stamps with the chosen wait + HEARTBEAT_MARGIN.
  HEARTBEAT_TTL = 30 * 60
  HEARTBEAT_MARGIN = 30 * 60

  def self.stamp_heartbeat(conversation_id, ttl: HEARTBEAT_TTL)
    DistributedLockManager.set_marker(heartbeat_key(conversation_id), ttl: ttl)
  end

  def self.chain_alive?(conversation_id)
    DistributedLockManager.marker?(heartbeat_key(conversation_id))
  end

  def self.heartbeat_key(conversation_id)
    "decision_chain_alive:#{conversation_id}"
  end

  # Recovery net for dead decision loops (the loop is a self-chaining
  # sequence of enqueues; a lost link silences the AI's initiative until the
  # user messages). The gate spares LIVE loops: reviving one can't fork it
  # anymore (the restart supersedes its parked link), but it would needlessly
  # cut healthy waits short and force an extra decision per sweep. Stamping
  # at schedule time makes the sweep idempotent across PeriodicTasksJob
  # retries.
  def self.revive_all(season)
    return unless season&.active?

    season.conversations.active_conversations.find_each do |conversation|
      next if chain_alive?(conversation.id)

      Rails.logger.warn "AiDecisionJob: reviving dead decision chain for conversation #{conversation.id}"
      stamp_heartbeat(conversation.id)
      restart_chain(conversation.id, jitter: true)
    end
  end

  private

  def mark_messages_as_read(conversation, before: nil)
    receipt_manager = Messaging::ReadReceiptManagerService.new(conversation)
    receipt_manager.mark_all_unread_user_messages_as_read!(before: before)

    Persona::Tools::ToolExecutorService.execute(
      season: conversation.season,
      conversation: conversation,
      context_description: 'after read-only',
      router: ai_router
    )
  end

end
