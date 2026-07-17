class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :season
  has_many :messages, dependent: :destroy
  has_one :user_state, dependent: :destroy

  validates :user_id, uniqueness: { scope: :season_id }

  after_create :create_user_state

  scope :active_conversations, -> { where(active: true) }

  def unread_user_messages
    messages.from_user.unread.order(:created_at)
  end

  def unread_ai_messages
    messages.from_ai.unread.order(:created_at)
  end

  def user_messages_since?(time)
    messages.from_user.where('created_at > ?', time).exists?
  end

  def ai_messages_since?(time)
    messages.from_ai.where('created_at > ?', time).exists?
  end

  # Idempotent: the nil-guarded update keeps the first timestamp under
  # concurrent marks
  def mark_farewell_delivered!
    self.class.where(id: id, farewell_sent_at: nil).update_all(farewell_sent_at: Time.current)
  end

  # Re-queries rather than reading a loaded attribute, so a concurrent mark
  # is never missed; all read paths delegate here
  def self.farewell_delivered?(conversation_id)
    where(id: conversation_id).where.not(farewell_sent_at: nil).exists?
  end

  def add_message(sender_type, content, is_fragment: false, fragment_index: nil)
    messages.create!(
      sender_type: sender_type,
      content: content,
      is_fragment: is_fragment,
      fragment_index: fragment_index
    )
  end

  def touch_last_message
    update_column(:last_message_at, Time.current)
  end

  def recent_messages(limit = 30)
    messages.order(created_at: :desc).limit(limit).reverse
  end

  private

  def create_user_state
    build_user_state(user: user).save!
  end
end
