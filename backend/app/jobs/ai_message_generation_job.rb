class AiMessageGenerationJob < ApplicationJob
  include AiRouterConcern
  include Interruptible

  queue_as :default

  # Retries must stay bounded: an unbounded retry that keeps refreshing the
  # lock TTL freezes the conversation under a persistent provider failure
  ai_pipeline_retry(release_lock: true) do |conversation_id, _options|
    AiDecisionJob.restart_chain(conversation_id, jitter: true)
  end

  def perform(conversation_id, action: 'respond', lock_token: nil)
    conversation = Conversation.find(conversation_id)
    return unless conversation.active?

    lock_key = DistributedLockManager.ai_decision_key(conversation_id)
    return if lock_ownership_lost?(conversation_id, lock_key, lock_token)

    action_type = action == 'initiate' ? 'thinking_before_initiate' : 'thinking_before_response'
    result = interruptible_thinking_pause(conversation, lock_key, lock_token, action_type, action)
    return if result[:interrupted]

    generator = Ai::MessageGenerator.new(router: ai_router)

    result = run_interruptible(conversation, lock_key, lock_token, 'message generation') do
      if action == 'initiate'
        generator.initiate_conversation(conversation)
      else
        unread_messages = conversation.unread_user_messages
        generator.generate_response(conversation, unread_messages)
      end
    end
    return if result[:interrupted]

    fragments = result[:value]

    # A non-interrupted return proves nothing arrived since started_at, so
    # it bounds the mark to exactly the messages the response incorporated;
    # anything later interrupts the fragment chain. The ownership re-check
    # keeps a stale flow from read-receipting messages a newer flow owns.
    interrupt_baseline = result[:started_at]

    if action == 'respond'
      return if lock_ownership_lost?(conversation_id, lock_key, lock_token)

      # Mark-before-enqueue is deliberate: a persistent enqueue failure
      # (Redis outage — the whole pipeline is down anyway) leaves receipts
      # without a response; the reverse order risks answering twice
      receipt_manager = Messaging::ReadReceiptManagerService.new(conversation)
      receipt_manager.mark_all_unread_user_messages_as_read!(before: interrupt_baseline)
    end

    FragmentSendJob.perform_later(
      conversation_id,
      fragments,
      lock_token: lock_token,
      interrupt_since: interrupt_baseline.to_f,
      chain_id: SecureRandom.uuid
    )
  end

  private

  # Refresh doubles as an ownership check. On loss, revive the decision loop
  # only when nobody owns the key — a live owner schedules its own follow-ups
  def lock_ownership_lost?(conversation_id, lock_key, lock_token)
    return false if lock_token.blank?
    return false if DistributedLockManager.refresh(lock_key, lock_token)

    Rails.logger.warn "AiMessageGenerationJob: lock ownership lost for conversation #{conversation_id}, aborting"
    AiDecisionJob.restart_chain(conversation_id, jitter: true) unless DistributedLockManager.held?(lock_key)
    true
  end

end
