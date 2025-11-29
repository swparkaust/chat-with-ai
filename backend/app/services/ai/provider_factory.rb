module Ai
  class ProviderFactory
    PROVIDERS = {
      'gemini' => 'Ai::Providers::GeminiProvider'
    }.freeze

    class << self
      def create
        db_provider = AiProvider.current

        if db_provider
          create_from_db(db_provider)
        else
          create_from_env
        end
      end

      def default
        return @default_provider if defined?(@default_provider) && @default_provider

        provider = create
        @default_provider = provider
        provider
      rescue StandardError => e
        Rails.logger.error "Failed to create default AI provider: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        raise
      end

      def reset_default!
        @default_provider = nil
      end

      private

      def create_from_db(db_provider)
        provider_class_name = PROVIDERS[db_provider.provider_type]

        unless provider_class_name
          available = PROVIDERS.keys.join(', ')
          raise ArgumentError, "Unknown AI provider '#{db_provider.provider_type}'. Available providers: #{available}"
        end

        provider_class = provider_class_name.constantize
        provider = provider_class.new(api_key: db_provider.api_key)

        unless provider.available?
          raise "AI provider '#{db_provider.name}' is not properly configured."
        end

        Rails.logger.info "Using AI provider from database: #{provider.provider_name}"
        provider
      rescue NameError => e
        raise "Failed to load AI provider '#{db_provider.provider_type}': #{e.message}"
      end

      def create_from_env
        provider_type = ENV.fetch('AI_PROVIDER', 'gemini')
        provider_class_name = PROVIDERS[provider_type]

        unless provider_class_name
          available = PROVIDERS.keys.join(', ')
          raise ArgumentError, "Unknown AI provider '#{provider_type}'. Available providers: #{available}"
        end

        provider_class = provider_class_name.constantize
        provider = provider_class.new

        unless provider.available?
          raise "AI provider '#{provider_type}' is not properly configured. Set GEMINI_API_KEY or configure via database."
        end

        Rails.logger.info "Using AI provider from ENV: #{provider.provider_name}"
        provider
      rescue NameError => e
        raise "Failed to load AI provider '#{provider_type}': #{e.message}"
      end
    end
  end
end
