class SeasonFarewellJob < ApplicationJob
  include AiRouterConcern

  queue_as :default

  # The farewell is one-shot per season (the warned flag is set at enqueue
  # time), so exhaustion re-parks instead of losing it. The in-method rescue
  # already released the lock. clear_pending first: a marker THIS dead
  # execution armed must not vouch against its own successor.
  ai_pipeline_retry do |conversation_id, _options|
    SeasonFarewellJob.clear_pending(conversation_id)
    SeasonFarewellJob.reschedule_if_undelivered(conversation_id)
  end

  RESCHEDULE_WAIT = 5.minutes
  # PENDING MARKER LIFECYCLE: one slot per conversation. Created AFTER a
  # successful enqueue in reschedule; KEPT (re-armed) while a parked or
  # busy-looping flow owns it; CONSUMED when a run commits (lock won) or the
  # need ends (season over / delivered). The TTL bounds a marker orphaned by
  # a hard kill; it must outlive the parked job through realistic backlogs
  # yet expire well inside PeriodicTasksJob::RESCHEDULE_INTERVAL, so a leak
  # suppresses at most one resend_missing sweep.
  PENDING_MARKER_TTL = (RESCHEDULE_WAIT + 10.minutes).to_i

  # Single owner of the retry cadence: at most ONE parked reschedule per
  # conversation, so recovery paths and the hourly sweep can call this freely
  # without multiplying loops under persistent generation failure.
  def self.reschedule(conversation_id)
    return false if DistributedLockManager.marker?(pending_key(conversation_id))

    set(wait: RESCHEDULE_WAIT).perform_later(conversation_id)
    # Marker AFTER the enqueue: a crash between the two yields a benign
    # duplicate park, not an orphaned marker that would suppress the farewell
    # AND the callers' follow-up decisions until the TTL cleared it.
    arm_pending(conversation_id)
    true
  end

  # Returns whether a farewell flow will carry the conversation forward,
  # so callers can skip their own follow-up decision
  def self.reschedule_if_undelivered(conversation_id)
    return false if delivered?(conversation_id)

    reschedule(conversation_id)
    true
  end

  # Returns whether a farewell flow will carry the conversation forward
  def self.settle_delivery(conversation_id, sent_count)
    if sent_count.to_i > 0
      mark_delivered(conversation_id)
      false
    else
      reschedule_if_undelivered(conversation_id)
    end
  end

  # Recovery net for chains lost to hard worker kills (no coded termination
  # path runs). Idempotent via the delivery record, pending marker, and lock;
  # a conversation delivered between scope read and park is caught by the
  # parked job's own checks.
  def self.resend_missing(season)
    return unless season&.active? && season.deactivation_warned_at.present?

    season.conversations.active_conversations.where(farewell_sent_at: nil).find_each do |conversation|
      reschedule(conversation.id)
    end
  end

  # Delivery is durable in Postgres (Conversation#mark_farewell_delivered!),
  # NOT Redis — a Redis wipe must not let the hourly resend net re-send
  # goodbyes that were already delivered. Id-based facades.
  def self.mark_delivered(conversation_id)
    Conversation.find_by(id: conversation_id)&.mark_farewell_delivered!
  end

  def self.delivered?(conversation_id)
    Conversation.farewell_delivered?(conversation_id)
  end

  def self.pending_key(conversation_id)
    "farewell_pending:#{conversation_id}"
  end

  def self.arm_pending(conversation_id)
    DistributedLockManager.set_marker(pending_key(conversation_id), ttl: PENDING_MARKER_TTL)
  end

  def self.clear_pending(conversation_id)
    DistributedLockManager.clear_marker(pending_key(conversation_id))
  end

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)

    # Terminal either way — consume the slot (lifecycle note above)
    if !conversation.active? || self.class.delivered?(conversation_id)
      self.class.clear_pending(conversation_id)
      return
    end

    lock_key = DistributedLockManager.ai_decision_key(conversation_id)
    lock_token = DistributedLockManager.acquire(lock_key)

    unless lock_token
      # Busy: re-arm the slot (a long contention window could outlive the
      # marker TTL) so settles and sweeps don't park duplicates meanwhile.
      # retry_job grows only the global executions counter; retry_on budgets
      # count per-class exception_executions, which busy waits don't consume.
      self.class.arm_pending(conversation_id)
      Rails.logger.info "Conversation #{conversation_id} busy, retrying farewell later"
      retry_job wait: 1.minute
      return
    end

    # Everything after winning the lock sits inside the rescue: no raise may
    # strand a ghost lock for its full TTL
    begin
      # Committed: consume the slot so a failure from here can park a successor
      self.class.clear_pending(conversation_id)

      # Post-acquire re-check: a dying prior chain may have delivered its
      # first fragment between our entry check and its last gasp
      if self.class.delivered?(conversation_id)
        DistributedLockManager.release(lock_key, lock_token)
        return
      end

      generator = Ai::MessageGenerator.new(router: ai_router)
      fragments = generator.generate_farewell(conversation)

      FragmentSendJob.perform_later(
        conversation_id,
        fragments,
        lock_token: lock_token,
        interrupt_since: Time.current.to_f,
        origin: 'farewell',
        chain_id: SecureRandom.uuid
      )
      lock_token = nil

      Rails.logger.info "Sent deactivation message to conversation #{conversation_id}"
    rescue StandardError
      # lock_token is nilled after the handoff. Residual: if perform_later
      # pushed AND raised, this releases the live chain's token — the chain
      # re-owns, and the delivery record blocks a duplicate farewell.
      DistributedLockManager.release(lock_key, lock_token)
      raise
    end
  end
end
