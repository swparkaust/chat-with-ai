module JsonbStateAccessor
  extend ActiveSupport::Concern

  included do
    before_save :normalize_state_data
  end

  def update_state(new_data)
    self.state_data = state_data.deep_merge(new_data)
    save!
  end

  def get_state(key)
    state_data.dig(*key.to_s.split('.'))
  end

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
