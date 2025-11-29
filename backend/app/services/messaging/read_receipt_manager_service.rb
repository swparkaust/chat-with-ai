module Messaging
  class ReadReceiptManagerService
    def initialize(conversation)
      @conversation = conversation
    end

    def mark_messages_as_read(message_ids, user_state = nil, bypass_focus: false)
      # Only mark as read if:
      # 1. User is focused on the window (tab is active) - unless bypassed (e.g., AI read-only action)
      # 2. Messages are in viewport (tracked by frontend)

      # Allow bypass when called from AI read-only action
      return unless bypass_focus || user_state&.is_focused

      messages_to_mark = @conversation.messages
                                     .where(id: message_ids, read_at: nil)

      marked_count = messages_to_mark.update_all(read_at: Time.current)

      if marked_count > 0
        broadcast_read_receipts(message_ids)
      end

      marked_count
    end

    def get_unread_count_for_user
      @conversation.unread_ai_messages.count
    end

    def get_unread_count_for_ai
      @conversation.unread_user_messages.count
    end

    private

    def broadcast_read_receipts(message_ids)
      message_ids.each do |message_id|
        ConversationChannel.broadcast_to(
          @conversation,
          {
            type: 'read_receipt',
            message_id: message_id
          }
        )
      end
    end
  end
end
