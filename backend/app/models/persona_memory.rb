class PersonaMemory < ApplicationRecord
  belongs_to :season

  validates :content, presence: true
  validates :significance, :emotional_intensity, :detail_level, presence: true, numericality: true
  validates :recall_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :memory_timestamp, presence: true

  scope :by_tags, ->(tags) { where('tags && ARRAY[?]::varchar[]', Array(tags)) }

  def self.create_from_ai!(season, data)
    attrs = {
      content: data['content'],
      significance: data['significance'] || 5.0,
      emotional_intensity: data['emotional_intensity'] || 5.0,
      tags: data['tags'] || [],
      memory_timestamp: Time.current
    }
    attrs[:detail_level] = data['detail_level'] if data['detail_level']

    season.persona_memories.create!(attrs)
  end

  def apply_decay!
    age_seconds = Time.current - memory_timestamp
    age_days = age_seconds / 1.day

    protection_factor = 0.3 + 0.7 * (emotional_intensity / 10.0)

    base_decay_rate = case
    when significance >= 9.0
      0.99
    when significance >= 7.0
      0.90
    when significance >= 4.0
      0.80
    else
      0.70
    end

    decay_power = age_days / 30.0
    new_detail = protection_factor * (base_decay_rate ** decay_power)
    new_detail = [new_detail, 0.05].max

    if (detail_level - new_detail).abs > 0.05
      update!(detail_level: new_detail)
      true
    else
      false
    end
  end

  def pruning_score
    age_days = (Time.current - memory_timestamp) / 1.day
    age_penalty = 1.0 / (1.0 + age_days / 30.0)
    recall_bonus = Math.log(recall_count + 1)
    emotional_weight = 1.0 + (emotional_intensity / 10.0)

    significance * detail_level * age_penalty * emotional_weight + recall_bonus
  end

  def similarity_to(other_memory)
    return 0.0 if tags.blank? || other_memory.tags.blank?

    shared_tags = tags & other_memory.tags
    return 0.0 if shared_tags.empty?

    (shared_tags.length.to_f / [tags.length, other_memory.tags.length].max) * 100.0
  end

  def age_in_days
    (Time.current - memory_timestamp) / 1.day
  end
end
