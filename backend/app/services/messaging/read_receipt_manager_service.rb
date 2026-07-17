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
      ids_to_mark = messages_to_mark.pluck(:id)
      return 0 if ids_to_mark.empty?

      read_at = Time.current
      marked_count = messages_to_mark.update_all(read_at: read_at)

      if marked_count > 0
        broadcast_read_receipts(ids_to_mark, read_at)
      end

      marked_count
    end

    # before: limits the mark to messages the AI has actually seen — later
    # arrivals stay unread so the interrupt/decision paths can catch them
    def mark_all_unread_user_messages_as_read!(before: nil)
      scope = @conversation.unread_user_messages
      scope = scope.where(created_at: ..before) if before

      mark_messages_as_read(scope.pluck(:id), nil, bypass_focus: true)
    end

    private

    def broadcast_read_receipts(message_ids, read_at)
      ConversationChannel.broadcast_to(
        @conversation,
        {
          type: 'read_receipt',
          message_ids: message_ids,
          read_at: read_at.iso8601
        }
      )
    end
  end
end
