class PushNotificationDeliveryJob < ApplicationJob
  queue_as :default

  # Exhaustion drops the push — accepted: the message persists in-app, and
  # a days-stale escalated notification would be worse than none

  def perform(user_id, title:, body:, icon: nil, badge: nil, url: nil, tag: nil)
    user = User.find_by(id: user_id)
    return unless user

    user.push_subscriptions.find_each do |subscription|
      subscription.send_notification(
        message: body,
        title: title,
        icon: icon,
        badge: badge,
        url: url,
        tag: tag
      )
    end
  end
end
