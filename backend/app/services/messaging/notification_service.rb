module Messaging
  class NotificationService
    DEFAULT_NOTIFICATION_TRUNCATE_LENGTH = 100

    def initialize(user)
      @user = user
    end

    def should_notify?(conversation, user_state)
      # Send notification if:
      # 1. User is not focused on the window, OR
      # 2. User is scrolled up reading history
      # Don't send if user is actively viewing the conversation

      !user_state.is_focused || user_state.scroll_position > 0
    end

    def send_new_message_notification(conversation, message)
      return unless should_notify?(conversation, conversation.user_state)

      full_name = conversation.season.full_name
      preview = truncate_message(message.content)

      send_push_notification(
        title: "#{full_name}",
        body: preview,
        icon: conversation.season.profile_picture,
        badge: '/badge-icon.png',
        url: "/chat/#{conversation.id}"
      )

      ring_notification_bell(conversation)
    end

    private

    def send_push_notification(title:, body:, icon: nil, badge: nil, url: nil)
      @user.push_subscriptions.each do |subscription|
        subscription.send_notification(
          message: body,
          title: title,
          icon: icon,
          badge: badge
        )
      end
    rescue StandardError => e
      Rails.logger.error "Failed to send push notification: #{e.message}"
    end

    def ring_notification_bell(conversation)
      ActionCable.server.broadcast(
        "conversation_#{conversation.id}",
        {
          type: 'notification_bell',
          ring: true
        }
      )
    end

    def truncate_message(content, length = DEFAULT_NOTIFICATION_TRUNCATE_LENGTH)
      content.length > length ? "#{content[0...length]}..." : content
    end
  end
end
