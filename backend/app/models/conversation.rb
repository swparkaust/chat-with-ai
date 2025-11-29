class Conversation < ApplicationRecord
  belongs_to :user
  belongs_to :season
  has_many :messages, dependent: :destroy
  has_one :user_state, dependent: :destroy

  validates :user_id, uniqueness: { scope: :season_id }

  after_create :create_user_state

  scope :active_conversations, -> { where(active: true) }
  scope :for_season, ->(season) { where(season: season) }
  scope :recently_active, -> { where('last_message_at > ?', 1.hour.ago) }

  def unread_user_messages
    messages.where(sender_type: 'user', read_at: nil).order(:created_at)
  end

  def unread_ai_messages
    messages.where(sender_type: 'ai', read_at: nil).order(:created_at)
  end

  def add_message(sender_type, content, is_fragment: false, fragment_index: nil)
    message = messages.create!(
      sender_type: sender_type,
      content: content,
      is_fragment: is_fragment,
      fragment_index: fragment_index
    )
    touch_last_message
    message
  end

  def touch_last_message
    update_column(:last_message_at, Time.current)
  end

  def deactivate!
    update!(active: false)
  end

  def recent_messages(limit = 30)
    messages.order(created_at: :desc).limit(limit).reverse
  end

  private

  def create_user_state
    build_user_state(user: user).save!
  end
end
