module Messaging
  class FragmentSenderService

    attr_reader :conversation

    def initialize(conversation)
      @conversation = conversation
      @message_broadcast_service = MessageBroadcastService.new(conversation)
      @typing_indicator_service = TypingIndicatorService.new(conversation)
      @notification_service = NotificationService.new(conversation.user)
    end

    def send_single_fragment(fragment, fragment_index, total_fragments, mark_farewell_delivered: false)
      message = @conversation.add_message(
        'ai',
        fragment,
        is_fragment: true,
        fragment_index: fragment_index
      )

      # Recorded at persistence — the instant the row is durably visible,
      # before the failure-prone broadcast/notification tail; same Postgres
      # as the message, so record and message can't diverge
      @conversation.mark_farewell_delivered! if mark_farewell_delivered

      @message_broadcast_service.broadcast_message(message)
      @notification_service.send_new_message_notification(@conversation, message)

      remaining_count = total_fragments - fragment_index - 1

      {
        should_reevaluate: remaining_count > 0 && rand < AppConstants::FRAGMENT_REEVALUATION_PROBABILITY
      }
    end

    def calculate_fragment_delays(fragments)
      persona_state = @conversation.season.persona_state
      timing_decider.get_fragment_delays(fragments, persona_state)
    end

    def fallback_typing_delay(fragment)
      char_count = fragment.length
      if char_count > 20
        AppConstants::TIMING_DELAY_FRAGMENT_LONG
      elsif char_count > 10
        AppConstants::TIMING_DELAY_FRAGMENT_MEDIUM
      else
        AppConstants::TIMING_DELAY_FRAGMENT_SHORT
      end
    end

    def reevaluate_fragments(fragments, current_index)
      sent_fragments = fragments[0...current_index + 1]
      remaining_fragments = fragments[current_index + 1..-1]

      return { continue: true } if remaining_fragments.blank?

      # Everything after this instant was NOT seen by the reevaluation: it
      # must stay unread and must count as an interruption on later hops
      snapshot_at = Time.current

      reevaluation_result = fragment_reevaluator.reevaluate_remaining_fragments(
        remaining_fragments,
        @conversation,
        sent_fragments
      )

      # A failed reevaluation never saw the thread — don't read-receipt
      # messages it never processed; they stay unread for finalize to catch
      mark_recent_user_messages_as_read(before: snapshot_at) unless reevaluation_result[:error]

      reevaluation_result.merge(snapshot_at: snapshot_at.to_f)
    end

    def user_interrupted?(since)
      @conversation.user_messages_since?(since)
    end

    def broadcast_typing(is_typing)
      @typing_indicator_service.broadcast_typing_status('ai', is_typing)
    end

    private

    # Lazy: the service is constructed on EVERY fragment hop, but only the
    # first hop (delays) and ~30% of send hops (reevaluation) need AI — and
    # pure-cleanup hops must not fail on provider config they don't use
    def router
      @router ||= AiProviders.build_router
    end

    def timing_decider
      @timing_decider ||= Ai::TimingDecider.new(router: router)
    end

    def fragment_reevaluator
      @fragment_reevaluator ||= Ai::FragmentReevaluator.new(router: router)
    end

    def mark_recent_user_messages_as_read(before: nil)
      receipt_manager = ReadReceiptManagerService.new(@conversation)
      receipt_manager.mark_all_unread_user_messages_as_read!(before: before)
    end
  end
end
