class UserState < ApplicationRecord
  belongs_to :user
  belongs_to :conversation

  validates :user_id, uniqueness: { scope: :conversation_id }

  scope :typing, -> { where('typing_at > ?', 5.seconds.ago) }
  scope :focused, -> { where(is_focused: true) }

  def typing?
    typing_at && typing_at > 5.seconds.ago
  end

  def start_typing!
    update!(typing_at: Time.current)
  end

  def stop_typing!
    update!(typing_at: nil)
  end

  def set_focused(focused)
    update!(is_focused: focused)
  end

  def update_scroll(position)
    update!(scroll_position: position)
  end

  def touch_seen
    update!(last_seen_at: Time.current)
  end

  def recently_seen?
    last_seen_at && last_seen_at > 30.seconds.ago
  end
end
