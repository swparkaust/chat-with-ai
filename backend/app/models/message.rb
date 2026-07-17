class Message < ApplicationRecord
  belongs_to :conversation

  validates :sender_type, presence: true, inclusion: { in: %w[user ai] }
  validates :content, presence: true

  after_create :update_conversation_timestamp

  scope :unread, -> { where(read_at: nil) }
  scope :from_user, -> { where(sender_type: 'user') }
  scope :from_ai, -> { where(sender_type: 'ai') }

  def user_message?
    sender_type == 'user'
  end

  def read?
    read_at.present?
  end

  private

  def update_conversation_timestamp
    conversation.touch_last_message
  end
end
