module Messaging
  class NotificationService
    DEFAULT_NOTIFICATION_TRUNCATE_LENGTH = 100

    def initialize(user)
      @user = user
    end

    def should_notify?(user_state)
      # Send notification if:
      # 1. User is not focused on the window, OR
      # 2. User is scrolled up reading history
      # Don't send if user is actively viewing the conversation

      !user_state.is_focused || user_state.scroll_position > 0
    end

    def send_new_message_notification(conversation, message)
      return unless should_notify?(conversation.user_state)

      full_name = conversation.season.full_name
      preview = truncate_message(message.content)

      PushNotificationDeliveryJob.perform_later(
        @user.id,
        title: "#{full_name}",
        body: preview,
        icon: AttachmentUrl.for(conversation.season.profile_picture),
        badge: '/icon-192x192.png',
        url: "/conversations/#{conversation.id}",
        tag: "conversation-#{conversation.id}"
      )

      ring_notification_bell(conversation)
    end

    private

    def ring_notification_bell(conversation)
      ConversationChannel.broadcast_to(
        conversation,
        {
          type: 'notification_bell'
        }
      )
    end

    def truncate_message(content, length = DEFAULT_NOTIFICATION_TRUNCATE_LENGTH)
      content.length > length ? "#{content[0...length]}..." : content
    end
  end
end
