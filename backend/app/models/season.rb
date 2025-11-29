class Season < ApplicationRecord
  has_one_attached :profile_picture

  has_one :persona_state, dependent: :destroy
  has_many :persona_memories, dependent: :destroy
  has_many :tool_states, dependent: :destroy
  has_many :conversations, dependent: :destroy

  validates :season_number, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }
  validates :start_date, presence: true
  validates :first_name, :last_name, presence: true, if: :active?

  before_validation :set_season_number, on: :create
  after_create :create_persona_state

  scope :ordered, -> { order(season_number: :desc) }

  def self.current
    find_by(active: true)
  end

  def self.create_new_season!
    transaction do
      current&.deactivate!
      create!(
        active: false,
        start_date: Time.current
      )
    end
  end

  def deactivate!
    update!(active: false, end_date: Time.current)
    conversations.update_all(active: false)
  end

  def should_warn_deactivation?
    return false unless active?
    return false if deactivation_warned_at.present?

    start_date < 10.weeks.ago
  end

  def should_rotate?
    return false unless active?
    start_date < 3.months.ago
  end

  def full_name
    "#{last_name}#{first_name}"
  end

  def mark_deactivation_warned!
    update!(deactivation_warned_at: Time.current)
  end

  private

  def set_season_number
    self.season_number ||= (Season.maximum(:season_number) || 0) + 1
  end

  def create_persona_state
    build_persona_state(state_data: {}).save!
  end
end
