class AiProvider < ApplicationRecord
  # Providers selectable via database configuration; AiProviders.build
  # resolves the stored key for the gemini branch (others use credentials/ENV)
  SUPPORTED_TYPES = %w[gemini anthropic ollama openai].freeze

  encrypts :api_key_encrypted, deterministic: false

  validates :name, :provider_type, presence: true
  validates :provider_type, inclusion: { in: SUPPORTED_TYPES }

  scope :active, -> { where(active: true) }

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
