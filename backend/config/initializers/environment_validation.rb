# frozen_string_literal: true

# Validate critical environment variables at startup
module EnvironmentValidation
  class << self
    def validate!
      check_vapid_keys
      check_redis_url
      warn_missing_optional_vars
    end

    private

    def check_vapid_keys
      missing_vapid = []
      missing_vapid << 'VAPID_PRIVATE_KEY' if ENV['VAPID_PRIVATE_KEY'].blank?
      missing_vapid << 'VAPID_PUBLIC_KEY' if ENV['VAPID_PUBLIC_KEY'].blank?
      missing_vapid << 'VAPID_SUBJECT' if ENV['VAPID_SUBJECT'].blank?

      if missing_vapid.any?
        Rails.logger.warn "⚠️  Missing VAPID configuration: #{missing_vapid.join(', ')}"
        Rails.logger.warn "⚠️  Push notifications will not work."
        Rails.logger.warn "   Generate keys with: rails webpush:generate_key"
        Rails.logger.warn "   Set VAPID_SUBJECT to your contact email (e.g., mailto:your-email@example.com)"
      end
    end

    def check_redis_url
      redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
      begin
        Redis.new(url: redis_url).ping
        Rails.logger.info "✓ Redis connection successful (#{redis_url})"
      rescue Redis::CannotConnectError => e
        Rails.logger.error "✗ Redis connection failed: #{e.message}"
        Rails.logger.error "  Sidekiq and caching will not work properly"
      end
    end

    def warn_missing_optional_vars
      # Check if AI provider is configured either via env or database
      has_env_provider = ENV['GEMINI_API_KEY'].present?

      unless has_env_provider
        Rails.logger.warn "⚠️  GEMINI_API_KEY not set in environment"
        Rails.logger.warn "   Make sure to configure AI provider via database (AiProvider model)"
      end

      if ENV['APP_VERSION'].blank?
        Rails.logger.info "ℹ️  APP_VERSION not set, will use default from database"
      end
    end
  end
end

# Run validation after Rails initialization
Rails.application.config.after_initialize do
  EnvironmentValidation.validate!
end
