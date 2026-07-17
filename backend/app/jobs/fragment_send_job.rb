class FragmentSendJob < ApplicationJob
  # Longer than any realistic chain. Also bounds first-hop re-owning, so a
  # duplicate delayed past the claim's expiry is abandoned, not resurrected.
  CHAIN_CLAIM_TTL = 900

  queue_as :default

  # NOTE: the serialized sent_count lags a final-attempt delivery by one.
  # Accepted: the farewell case is covered by the in-service delivery record,
  # and a skipped evolution self-heals on the next flow.
  ai_pipeline_retry(release_lock: true) do |conversation_id, options|
    AiStateEvolutionJob.perform_later(conversation_id) if options[:sent_count].to_i > 0

    unless options[:origin] == 'farewell' && SeasonFarewellJob.settle_delivery(conversation_id, options[:sent_count])
      AiDecisionJob.restart_chain(conversation_id, jitter: true)
    end
  end

  def perform(conversation_id, fragments, fragment_index: 0, sent_count: 0, phase: 'typing', delays: nil, interrupt_since: nil, lock_token: nil, origin: nil, chain_id: nil, hop_enqueued_at: nil)
    conversation = Conversation.find(conversation_id)

    lock_key = DistributedLockManager.ai_decision_key(conversation_id)
    sender = Messaging::FragmentSenderService.new(conversation)
    first_hop = fragment_index.zero? && phase == 'typing'

    # Every self-enqueue merges into this, so a new chain parameter cannot
    # silently miss a requeue site. The lambda reads locals at CALL time,
    # picking up post-reevaluation mutations of fragments/delays/baseline.
    next_hop_state = lambda do |overrides = {}|
      {
        fragment_index: fragment_index,
        sent_count: sent_count,
        phase: phase,
        delays: delays,
        interrupt_since: interrupt_since,
        lock_token: lock_token,
        origin: origin,
        chain_id: chain_id,
        hop_enqueued_at: Time.current.to_f
      }.merge(overrides)
    end

    begin
      unless conversation.active?
        sender.broadcast_typing(false)
        DistributedLockManager.release(lock_key, lock_token)
        return
      end

      # Enqueues are at-least-once: a producer retry can push the same chain
      # twice with one lock token. Exactly one sibling wins the claim
      # (retries of the winner share its chain_id and pass); the check runs
      # before the ownership guard so a loser never touches the lock.
      claim_verified = false
      if first_hop && chain_id.present? && lock_token.present?
        unless DistributedLockManager.claim("fragment_chain:#{lock_token}", chain_id, ttl: CHAIN_CLAIM_TTL)
          Rails.logger.warn "FragmentSendJob: duplicate chain for conversation #{conversation_id}, aborting"
          return
        end
        claim_verified = true
      end

      # Refresh doubles as ownership check and TTL extension. On failure:
      # another flow owns the key (abort — the owner does the owed work) or
      # it expired unowned. Re-owning an expired key requires the chain to be
      # provably safe to resume —
      #   mid-chain: last hop enqueued within the lock TTL (older chains may
      #   have been superseded by a complete newer flow);
      #   first hop: claim verified THIS run, chain younger than the claim's
      #   own lifetime (an expired claim can't vouch for uniqueness), and no
      #   AI message postdates the baseline (an initiate flow may have run
      #   during the backlog). First hops without a verified claim (no
      #   chain_id in args) fail closed.
      if lock_token.present? && !DistributedLockManager.refresh(lock_key, lock_token)
        resumable =
          if first_hop
            age = interrupt_since && Time.current.to_f - interrupt_since
            claim_verified && age && age <= CHAIN_CLAIM_TTL &&
              !conversation.ai_messages_since?(Time.zone.at(interrupt_since))
          else
            last_activity = hop_enqueued_at || interrupt_since
            last_activity.nil? || Time.current.to_f - last_activity <= DistributedLockManager::DEFAULT_TTL
          end

        unless resumable
          abandon_chain(conversation_id, sender, sent_count, origin)
          return
        end

        new_token = DistributedLockManager.acquire(lock_key)

        if new_token
          # Re-enqueue rather than continue inline: the adopted token must be
          # persisted in job args, where retries and exhaustion read it
          Rails.logger.warn "FragmentSendJob: lock expired unowned for conversation #{conversation_id}, re-owning and resuming"
          FragmentSendJob.perform_later(conversation_id, fragments, **next_hop_state.call(lock_token: new_token))
        else
          abandon_chain(conversation_id, sender, sent_count, origin)
        end
        return
      end

      interrupt_since = Time.current.to_f if interrupt_since.nil?

      if delays.nil? && first_hop
        delays = sender.calculate_fragment_delays(fragments)
      end

      if fragment_index >= fragments.length
        finalize_sending(conversation, sent_count, interrupted: false, lock_token: lock_token, origin: origin)
        return
      end

      if sender.user_interrupted?(Time.zone.at(interrupt_since))
        Rails.logger.info "User interrupted before fragment #{fragment_index + 1}"
        sender.broadcast_typing(false) if phase == 'send'
        finalize_sending(conversation, sent_count, interrupted: true, lock_token: lock_token, origin: origin)
        return
      end

      if phase == 'typing'
        fragment = fragments[fragment_index]
        typing_delay = (delays && delays[fragment_index]) || sender.fallback_typing_delay(fragment)

        sender.broadcast_typing(true)

        FragmentSendJob.set(wait: typing_delay.seconds)
                       .perform_later(conversation_id, fragments, **next_hop_state.call(phase: 'send'))
        return

      elsif phase == 'send'
        result = sender.send_single_fragment(
          fragments[fragment_index],
          fragment_index,
          fragments.length,
          mark_farewell_delivered: origin == 'farewell' && sent_count.zero?
        )
        sender.broadcast_typing(false)

        new_sent_count = sent_count + 1

        if result[:should_reevaluate] && fragment_index < fragments.length - 1
          reevaluation = sender.reevaluate_fragments(fragments, fragment_index)

          # A failed reevaluation never saw the thread: keep the old baseline
          # so unseen messages still interrupt later hops
          if reevaluation[:snapshot_at] && !reevaluation[:error]
            interrupt_since = reevaluation[:snapshot_at]
          end

          unless reevaluation[:continue]
            Rails.logger.info "AI decided to stop sending after fragment #{fragment_index + 1}"
            finalize_sending(conversation, new_sent_count, interrupted: false, lock_token: lock_token, origin: origin)
            return
          end

          if reevaluation[:fragments].is_a?(Array)
            new_delays = sender.calculate_fragment_delays(reevaluation[:fragments])
            fragments, delays = splice_remaining(fragments, fragment_index, reevaluation[:fragments], new_delays)
            Rails.logger.info "Using updated fragments: #{reevaluation[:fragments].length} remaining"
          end
        end

        if fragment_index + 1 < fragments.length
          FragmentSendJob.perform_later(
            conversation_id,
            fragments,
            **next_hop_state.call(fragment_index: fragment_index + 1, sent_count: new_sent_count, phase: 'typing')
          )
        else
          finalize_sending(conversation, new_sent_count, interrupted: false, lock_token: lock_token, origin: origin)
        end
      end

    rescue StandardError => e
      # Keep the lock so the retry (same args, same token) still owns the
      # flow. Known gap: at-least-once delivery means a retry can re-send the
      # current fragment, and a crash-redelivered hop whose successor already
      # enqueued forks the chain, duplicating the remainder — closing that
      # needs a unique index on conversation/chain/fragment position.
      Rails.logger.error "Fragment sending failed: #{e.message}, retrying with lock held"
      sender.broadcast_typing(false) rescue nil
      raise
    end
  end

  private

  # Settle a chain that lost its lock and must not resume. A live owner's
  # finalize evolves the shared history and schedules decisions — doing both
  # here too would double-apply persona churn. held? is a point-in-time
  # probe; an owner releasing microseconds earlier costs one redundant
  # settle (accepted).
  def abandon_chain(conversation_id, sender, sent_count, origin)
    Rails.logger.warn "FragmentSendJob: abandoning chain for conversation #{conversation_id}"
    sender.broadcast_typing(false)

    owner_alive = DistributedLockManager.held?(DistributedLockManager.ai_decision_key(conversation_id))

    AiStateEvolutionJob.perform_later(conversation_id) if sent_count > 0 && !owner_alive

    farewell_carried = origin == 'farewell' && SeasonFarewellJob.settle_delivery(conversation_id, sent_count)

    AiDecisionJob.restart_chain(conversation_id, jitter: true) unless owner_alive || farewell_carried
  end

  # Keeps fragments and per-index delays aligned: already-sent positions get
  # nil delays, which are never looked up again
  def splice_remaining(fragments, fragment_index, new_fragments, new_delays)
    sent_fragments = fragments[0..fragment_index]
    [
      sent_fragments + new_fragments,
      new_delays ? Array.new(sent_fragments.length) + new_delays : nil
    ]
  end

  def finalize_sending(conversation, sent_count, interrupted:, lock_token:, origin: nil)
    # Everything after delivery — including the release — is best-effort: a
    # re-raise here would retry the hop and re-send the delivered fragment.
    # Lost bookkeeping is recovered by the hourly nets (AiDecisionJob
    # .revive_all, SeasonFarewellJob.resend_missing) and later evolution
    # flows. The owed decision is scheduled first so a bookkeeping error
    # can't silence a conversation with unread messages.
    begin
      DistributedLockManager.release(DistributedLockManager.ai_decision_key(conversation.id), lock_token)

      if interrupted
        Rails.logger.info "Fragment sending interrupted after #{sent_count} fragments"
        AiDecisionJob.restart_chain(conversation.id)
      else
        unread_count = conversation.unread_user_messages.count
        if unread_count > 0
          Rails.logger.info "#{unread_count} unread messages detected, scheduling immediate AI decision"
          AiDecisionJob.restart_chain(conversation.id)
        else
          AiDecisionJob.restart_chain(conversation.id, jitter: true)
        end
      end

      # Unlike the exhaustion/abandon callers, the settle return must NOT
      # gate the decisions above: an interrupted zero-delivery farewell means
      # unanswered user messages, so the decision is owed regardless
      SeasonFarewellJob.settle_delivery(conversation.id, sent_count) if origin == 'farewell'

      AiStateEvolutionJob.perform_later(conversation.id)
    rescue StandardError => e
      Rails.logger.error "FragmentSendJob: finalize bookkeeping failed for conversation #{conversation.id}: #{e.message}"
    end
  end

end
