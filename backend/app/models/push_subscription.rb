class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, :auth_key, presence: true

  def subscription_info
    {
      endpoint: endpoint,
      keys: {
        p256dh: p256dh_key,
        auth: auth_key
      }
    }
  end

  def send_notification(message:, title: nil, icon: nil, badge: nil)
    Webpush.payload_send(
      message: JSON.generate({
        title: title || "새 메시지",
        body: message,
        icon: icon,
        badge: badge
      }),
      endpoint: endpoint,
      p256dh: p256dh_key,
      auth: auth_key,
      vapid: {
        subject: ENV.fetch('VAPID_SUBJECT'),
        public_key: ENV.fetch('VAPID_PUBLIC_KEY'),
        private_key: ENV.fetch('VAPID_PRIVATE_KEY')
      }
    )
  rescue Webpush::InvalidSubscription, Webpush::Unauthorized, Webpush::ExpiredSubscription => e
    Rails.logger.warn "Push subscription #{id} is invalid: #{e.message}"
    destroy
    false
  rescue StandardError => e
    Rails.logger.error "Failed to send push notification: #{e.message}"
    false
  end
end
