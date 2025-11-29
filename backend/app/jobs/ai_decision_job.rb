class AiDecisionJob < ApplicationJob
  include AiProviderConcern

  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    return unless conversation.active?

    lock_key = "ai_decision_lock:#{conversation_id}"
    lock_acquired = DistributedLockManager.acquire(lock_key)

    unless lock_acquired
      Rails.logger.info "AiDecisionJob already running for conversation #{conversation_id}, skipping"
      return
    end

    original_unread_count = conversation.unread_user_messages.count
    decider = Ai::ActionDecider.new(default_ai_provider)

    decision = nil
    api_thread = Thread.new { decider.decide_action(conversation) }

    while api_thread.alive?
      conversation.reload
      current_unread_count = conversation.unread_user_messages.count
      if current_unread_count > original_unread_count
        Rails.logger.info "User interrupted during AI decision, cancelling and requeueing"
        api_thread.kill
        DistributedLockManager.release(lock_key)
        AiDecisionJob.perform_later(conversation_id)
        return
      end
      sleep 0.1
    end

    decision = api_thread.value

    Rails.logger.info "AI decision for conversation #{conversation_id}: #{decision[:action]}"

    case decision[:action]
    when 'respond'
      AiMessageGenerationJob.perform_later(conversation_id, action: 'respond')
    when 'read_only'
      mark_messages_as_read(conversation)
      DistributedLockManager.release(lock_key)
      AiDecisionJob.set(wait: rand(AppConstants::AI_DECISION_MIN_DELAY..AppConstants::AI_DECISION_MAX_DELAY).seconds)
                    .perform_later(conversation_id)
    when 'wait'
      DistributedLockManager.release(lock_key)
      AiDecisionJob.set(wait: decision[:wait_seconds].seconds)
                    .perform_later(conversation_id)
    when 'initiate'
      AiMessageGenerationJob.perform_later(conversation_id, action: 'initiate')
    end
  rescue StandardError => e
    Rails.logger.error "AiDecisionJob failed: #{e.message}, lock will expire naturally"
    raise
  end

  private

  def mark_messages_as_read(conversation)
    unread_messages = conversation.unread_user_messages
    message_ids = unread_messages.pluck(:id)

    receipt_manager = Messaging::ReadReceiptManagerService.new(conversation)
    receipt_manager.mark_messages_as_read(message_ids, nil, bypass_focus: true)

    execute_tools_after_read_only(conversation)
  end

  def execute_tools_after_read_only(conversation)
    recent_messages = conversation.recent_messages(15)

    Persona::Tools::ToolExecutorService.execute(
      season: conversation.season,
      conversation: conversation,
      recent_messages: recent_messages,
      context_description: 'after read-only'
    )
  end

end
