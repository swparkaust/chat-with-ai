class AiProvider < ApplicationRecord
  encrypts :api_key_encrypted, deterministic: false

  validates :name, :provider_type, presence: true
  validates :provider_type, inclusion: { in: ->(_) { Ai::ProviderFactory::PROVIDERS.keys } }

  scope :active, -> { where(active: true) }
  scope :by_type, ->(type) { where(provider_type: type) }

  def self.current
    active.first
  end

  def api_key=(value)
    self.api_key_encrypted = value
  end

  def api_key
    api_key_encrypted
  end

  def activate!
    AiProvider.update_all(active: false)
    update!(active: true)
  end
end
