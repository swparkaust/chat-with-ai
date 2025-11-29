class AiMessageGenerationJob < ApplicationJob
  include AiProviderConcern

  queue_as :default

  def perform(conversation_id, action: 'respond', skip_thinking: false, unread_count_before: nil)
    conversation = Conversation.find(conversation_id)
    return unless conversation.active?

    lock_key = "ai_decision_lock:#{conversation_id}"

    unless skip_thinking
      timing_decider = Ai::TimingDecider.new(default_ai_provider)

      thinking_delay = get_thinking_delay(timing_decider, conversation, action)

      if thinking_delay > 0
        Rails.logger.info "AI will think for #{thinking_delay.round(2)}s before #{action}..."

        original_unread_count = conversation.unread_user_messages.count
        elapsed = 0
        check_interval = 0.1

        while elapsed < thinking_delay
          conversation.reload
          current_unread_count = conversation.unread_user_messages.count
          if current_unread_count > original_unread_count
            Rails.logger.info "User interrupted during thinking delay, cancelling"
            DistributedLockManager.release(lock_key)
            AiDecisionJob.perform_later(conversation_id)
            return
          end
          sleep_time = [check_interval, thinking_delay - elapsed].min
          sleep sleep_time
          elapsed += check_interval
        end
      end
    end

    original_unread_count = conversation.unread_user_messages.count
    generator = Ai::MessageGenerator.new(default_ai_provider)

    fragments = nil
    api_thread = Thread.new do
      if action == 'initiate'
        generator.initiate_conversation(conversation)
      else
        unread_messages = conversation.unread_user_messages
        generator.generate_response(conversation, unread_messages)
      end
    end

    while api_thread.alive?
      conversation.reload
      current_unread_count = conversation.unread_user_messages.count
      if current_unread_count > original_unread_count
        Rails.logger.info "User interrupted during message generation, cancelling"
        api_thread.kill
        DistributedLockManager.release(lock_key)
        AiDecisionJob.perform_later(conversation_id)
        return
      end
      sleep 0.1
    end

    fragments = api_thread.value

    if action == 'respond'
      unread_messages = conversation.unread_user_messages
      message_ids = unread_messages.pluck(:id)

      receipt_manager = Messaging::ReadReceiptManagerService.new(conversation)
      receipt_manager.mark_messages_as_read(message_ids, nil, bypass_focus: true)
    end

    FragmentSendJob.perform_later(conversation_id, fragments)

  rescue StandardError => e
    Rails.logger.error "AI message generation failed: #{e.message}"
    retry_job wait: 30.seconds
  end

  private

  def get_thinking_delay(timing_decider, conversation, action)
    persona_state = conversation.season.persona_state

    action_type = case action
    when 'initiate'
      'thinking_before_initiate'
    when 'read_only'
      'thinking_before_read_only'
    else
      'thinking_before_response'
    end

    timing_decider.get_timing_decision(action_type, persona_state)
  rescue StandardError => e
    Rails.logger.warn "Thinking delay decision failed: #{e.message}, using default"
    case action
    when 'initiate'
      1.5
    when 'read_only'
      0.8
    else
      1.0
    end
  end

end
