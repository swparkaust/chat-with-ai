class PersonaState < ApplicationRecord
  include JsonbStateAccessor

  belongs_to :season

  validates :state_data, exclusion: { in: [nil] }

  def age
    return nil unless state_data['birthday_year']
    now = Time.current
    age = now.year - state_data['birthday_year']
    birthday_this_year = Date.new(now.year, state_data['birthday_month'] || 1, state_data['birthday_day'] || 1)
    age -= 1 if now.to_date < birthday_this_year
    age
  end

  def emotions
    state_data['emotions'] || []
  end

  def context
    state_data['context']
  end

  def emotion_description
    state_data['emotion_description']
  end
end
