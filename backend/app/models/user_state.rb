class UserState < ApplicationRecord
  MAX_SCROLL_POSITION = 1_000_000

  belongs_to :user
  belongs_to :conversation

  validates :user_id, uniqueness: { scope: :conversation_id }

  def typing?
    typing_at && typing_at > AppConstants::TYPING_INDICATOR_TIMEOUT.ago
  end

  def typing=(value)
    self.typing_at = value ? Time.current : nil
  end

  def scroll_position=(value)
    super(value.to_i.clamp(0, MAX_SCROLL_POSITION))
  end

  def start_typing!
    update!(typing: true)
  end

  def stop_typing!
    update!(typing: false)
  end
end
