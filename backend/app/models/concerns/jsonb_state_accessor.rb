module JsonbStateAccessor
  extend ActiveSupport::Concern

  included do
    before_save :normalize_state_data
  end

  def get_state(key)
    state_data.dig(*key.to_s.split('.'))
  end

  # Non-atomic read-modify-write: last writer wins over the whole
  # state_data column, so concurrent writers (hourly trigger sweep vs
  # per-conversation tool chains) can drop each other's changes. Callers
  # must tolerate rare lost updates — for trigger fire-once marks that
  # means at worst one duplicate fire.
  def set_state(key, value)
    updated_data = state_data.dup
    keys = key.to_s.split('.')
    current = updated_data
    keys[0...-1].each do |k|
      current[k] ||= {}
      current = current[k]
    end
    current[keys.last] = value
    self.state_data = updated_data
    save!
  end

  private

  def normalize_state_data
    self.state_data ||= {}
  end
end
