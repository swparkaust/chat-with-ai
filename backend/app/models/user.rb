class User < ApplicationRecord
  MAX_NAME_LENGTH = 100
  MAX_STATUS_MESSAGE_LENGTH = 500

  has_one_attached :profile_picture

  has_many :conversations, dependent: :destroy
  has_many :user_states, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  validates :device_id, presence: true, uniqueness: true
  validates :name, length: { maximum: MAX_NAME_LENGTH }, allow_nil: true
  validates :status_message, length: { maximum: MAX_STATUS_MESSAGE_LENGTH }, allow_nil: true

  before_create :set_default_name
  after_commit :update_last_seen, on: [:create, :update]

  def active?
    last_seen_at&.> 24.hours.ago
  end

  def touch_last_seen
    update_column(:last_seen_at, Time.current)
  end

  def identifier
    name_value = name || '상대방'
    "#{name_value} (##{id})"
  end

  private

  def set_default_name
    self.name ||= "사용자 #{device_id[0..7]}"
  end

  def update_last_seen
    touch_last_seen unless last_seen_at&.> 1.minute.ago
  end
end
