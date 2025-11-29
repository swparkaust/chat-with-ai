class FragmentSendJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, fragments, fragment_index: 0, sent_count: 0, phase: 'typing')
    conversation = Conversation.find(conversation_id)
    return unless conversation.active?

    lock_key = "ai_decision_lock:#{conversation_id}"
    sender = Messaging::FragmentSenderService.new(conversation)
    finalized = false

    begin
      if fragment_index >= fragments.length
        finalize_sending(conversation_id, conversation, fragments, sent_count, interrupted: false)
        finalized = true
        return
      end

      if sender.user_interrupted?
        Rails.logger.info "User interrupted before fragment #{fragment_index + 1}"
        sender.broadcast_typing(false) if phase == 'send'
        finalize_sending(conversation_id, conversation, fragments, sent_count, interrupted: true)
        finalized = true
        return
      end

      if phase == 'typing'
        fragment = fragments[fragment_index]
        remaining_count = fragments.length - fragment_index - 1
        typing_delay = sender.calculate_typing_delay(fragment, remaining_count)

        sender.broadcast_typing(true)

        FragmentSendJob.set(wait: typing_delay.seconds).perform_later(
          conversation_id,
          fragments,
          fragment_index: fragment_index,
          sent_count: sent_count,
          phase: 'send'
        )
        finalized = true
        return

      elsif phase == 'send'
        result = sender.send_single_fragment(fragments[fragment_index], fragment_index, fragments.length)
        sender.broadcast_typing(false)

        new_sent_count = sent_count + 1

        if result[:should_reevaluate] && fragment_index < fragments.length - 1
          reevaluation = sender.reevaluate_fragments(fragments, fragment_index, new_sent_count)

          unless reevaluation[:continue]
            Rails.logger.info "AI decided to stop sending after fragment #{fragment_index + 1}"
            finalize_sending(conversation_id, conversation, fragments, new_sent_count, interrupted: false)
            finalized = true
            return
          end

          if reevaluation[:fragments] && reevaluation[:fragments].is_a?(Array)
            sent_fragments = fragments[0..fragment_index]
            fragments = sent_fragments + reevaluation[:fragments]
            Rails.logger.info "Using updated fragments: #{reevaluation[:fragments].length} remaining"
          end
        end

        if fragment_index + 1 < fragments.length
          FragmentSendJob.perform_later(
            conversation_id,
            fragments,
            fragment_index: fragment_index + 1,
            sent_count: new_sent_count,
            phase: 'typing'
          )
          finalized = true
        else
          finalize_sending(conversation_id, conversation, fragments, new_sent_count, interrupted: false)
          finalized = true
        end
      end

    rescue StandardError => e
      Rails.logger.error "Fragment sending failed: #{e.message}"
      sender.broadcast_typing(false) rescue nil
      raise
    ensure
      # Release lock if finalize_sending wasn't called (error before finalization)
      unless finalized
        Rails.logger.warn "FragmentSendJob: Releasing lock due to error or unexpected exit"
        DistributedLockManager.release(lock_key)
      end
    end
  end

  private

  def finalize_sending(conversation_id, conversation, fragments, sent_count, interrupted:)
    lock_key = "ai_decision_lock:#{conversation_id}"

    begin
      AiStateEvolutionJob.perform_later(conversation_id)

      if interrupted
        Rails.logger.info "Fragment sending interrupted after #{sent_count} fragments"
        AiDecisionJob.perform_later(conversation_id)
      else
        execute_tools_after_response(conversation)

        unread_count = conversation.messages.where(sender_type: 'user', read_at: nil).count
        if unread_count > 0
          Rails.logger.info "#{unread_count} unread messages detected, scheduling immediate AI decision"
          AiDecisionJob.perform_later(conversation_id)
        else
          AiDecisionJob.set(wait: rand(AppConstants::AI_DECISION_MIN_DELAY..AppConstants::AI_DECISION_MAX_DELAY).seconds)
                        .perform_later(conversation_id)
        end
      end
    ensure
      DistributedLockManager.release(lock_key)
    end
  end

  def execute_tools_after_response(conversation)
    recent_messages = conversation.recent_messages(15)

    Persona::Tools::ToolExecutorService.execute(
      season: conversation.season,
      conversation: conversation,
      recent_messages: recent_messages,
      context_description: 'after response'
    )
  end

end
