module Messaging
  class FragmentSenderService

    attr_reader :conversation

    def initialize(conversation)
      @conversation = conversation
      @provider = Ai::ProviderFactory.default
      @timing_decider = Ai::TimingDecider.new(@provider)
      @fragment_reevaluator = Ai::FragmentReevaluator.new(@provider)
      @last_interrupt_check = Time.current
      @message_broadcast_service = MessageBroadcastService.new(conversation)
      @typing_indicator_service = TypingIndicatorService.new(conversation)
      @notification_service = NotificationService.new(conversation.user)
    end

    def send_single_fragment(fragment, fragment_index, total_fragments)
      message = @conversation.add_message(
        'ai',
        fragment,
        is_fragment: true,
        fragment_index: fragment_index
      )

      @message_broadcast_service.broadcast_message(message)
      @notification_service.send_new_message_notification(@conversation, message)

      remaining_count = total_fragments - fragment_index - 1
      next_delay = remaining_count > 0 ? get_ai_driven_delay(fragment, remaining_count) : 0

      {
        interrupted: false,
        should_reevaluate: remaining_count > 0 && rand < AppConstants::FRAGMENT_REEVALUATION_PROBABILITY,
        next_delay: next_delay
      }
    end

    def calculate_typing_delay(fragment, remaining_count)
      get_ai_driven_delay(fragment, remaining_count)
    end

    def reevaluate_fragments(fragments, current_index, sent_count)
      sent_fragments = fragments[0...current_index + 1]
      remaining_fragments = fragments[current_index + 1..-1]

      if remaining_fragments.blank?
        return { continue: true, fragments: [], reason: 'No remaining fragments' }
      end

      reevaluation_result = @fragment_reevaluator.reevaluate_remaining_fragments(
        remaining_fragments,
        @conversation,
        sent_fragments
      )

      mark_recent_user_messages_as_read

      unless reevaluation_result[:continue]
        Rails.logger.info "Reevaluation: Stop sending (reason: #{reevaluation_result[:reason]})"
      end

      reevaluation_result
    end

    def user_interrupted?
      last_check = @last_interrupt_check || Time.current - 5.seconds
      @last_interrupt_check = Time.current

      @conversation.messages
                  .where(sender_type: 'user')
                  .where('created_at > ?', last_check)
                  .exists?
    end

    def broadcast_typing(is_typing)
      @typing_indicator_service.broadcast_typing_status('ai', is_typing)
    end

    private

    def mark_recent_user_messages_as_read
      unread_messages = @conversation.messages
                                    .where(sender_type: 'user')
                                    .where(read_at: nil)
      message_ids = unread_messages.pluck(:id)

      return if message_ids.empty?

      receipt_manager = ReadReceiptManagerService.new(@conversation)
      receipt_manager.mark_messages_as_read(message_ids, nil, bypass_focus: true)
    end

    def get_ai_driven_delay(fragment, remaining_count)
      persona_state = @conversation.season.persona_state
      context = {
        'fragment' => fragment,
        'remaining_count' => remaining_count,
        'fragment_length' => fragment.length
      }

      @timing_decider.get_timing_decision(
        'delay_between_fragments',
        persona_state,
        context
      )
    rescue StandardError => e
      Rails.logger.warn "AI timing decision failed: #{e.message}, using fallback"
      char_count = fragment.length
      if char_count > 20
        AppConstants::TIMING_DELAY_FRAGMENT_LONG
      elsif char_count > 10
        AppConstants::TIMING_DELAY_FRAGMENT_MEDIUM
      else
        AppConstants::TIMING_DELAY_FRAGMENT_SHORT
      end
    end
  end
end
