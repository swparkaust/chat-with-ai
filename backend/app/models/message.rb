class Message < ApplicationRecord
  belongs_to :conversation

  validates :sender_type, presence: true, inclusion: { in: %w[user ai] }
  validates :content, presence: true

  after_create :update_conversation_timestamp

  scope :unread, -> { where(read_at: nil) }
  scope :from_user, -> { where(sender_type: 'user') }
  scope :from_ai, -> { where(sender_type: 'ai') }
  scope :ordered, -> { order(created_at: :asc) }
  scope :recent, ->(limit = 30) { ordered.last(limit) }

  def user_message?
    sender_type == 'user'
  end

  def ai_message?
    sender_type == 'ai'
  end

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.current) unless read?
  end

  private

  def update_conversation_timestamp
    conversation.touch_last_message
  end
end
