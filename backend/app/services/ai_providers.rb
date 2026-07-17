module AiProviders
  def self.build
    # A database AiProvider record (admin-configured, encrypted key) takes
    # precedence over ENV for both provider selection and key resolution
    db_provider = AiProvider.current
    provider_type = db_provider&.provider_type || ENV.fetch("AI_PROVIDER", "gemini")

    adapter = case provider_type
    when "gemini"
      api_key = resolve_api_key(db_provider, :gemini_api_key, "GEMINI_API_KEY")

      models = if ENV["GEMINI_ADVANCED_MODEL"]
        {
          advanced: ENV["GEMINI_ADVANCED_MODEL"],
          standard: ENV.fetch("GEMINI_STANDARD_MODEL", ENV["GEMINI_ADVANCED_MODEL"])
        }
      elsif ENV["GEMINI_MODEL"]
        { advanced: ENV["GEMINI_MODEL"], standard: ENV["GEMINI_MODEL"] }
      end

      GeminiAdapter.new(api_key: api_key, models: models)
    when "anthropic"
      api_key = resolve_api_key(db_provider, :claude_api_key, "ANTHROPIC_API_KEY")

      AnthropicAdapter.new(api_key: api_key)
    when "ollama"
      OllamaAdapter.new(host: ENV.fetch("OLLAMA_HOST", "http://localhost:11434"))
    when "openai"
      api_key = resolve_api_key(db_provider, :openai_api_key, "OPENAI_API_KEY")

      base_url = ENV["OPENAI_BASE_URL"]
      models = ENV["OPENAI_ADVANCED_MODEL"] ? {
        advanced: ENV["OPENAI_ADVANCED_MODEL"],
        standard: ENV.fetch("OPENAI_STANDARD_MODEL", ENV["OPENAI_ADVANCED_MODEL"])
      } : nil

      OpenaiAdapter.new(api_key: api_key, base_url: base_url, models: models)
    else
      raise ArgumentError, "Unknown AI provider: #{provider_type}. Valid: gemini, anthropic, ollama, openai"
    end

    # Provenance matters when keys go stale: resolution spans three silent
    # tiers (DB record > credentials > ENV) and adapters degrade instead of
    # raising, so this line is the only breadcrumb naming which source won.
    # Failed builds raise out of the case above and are never logged as in
    # use.
    Rails.logger.info "Using AI provider from #{db_provider ? 'database' : 'ENV'}: #{provider_type}"

    adapter
  end

  def self.resolve_api_key(db_provider, credential_key, env_key)
    api_key = db_provider&.api_key.presence ||
              Rails.application.credentials.dig(credential_key) ||
              ENV[env_key]
    raise "#{env_key} not configured" if api_key.blank?

    api_key
  end
  private_class_method :resolve_api_key

  def self.build_router
    provider = build
    model_map = if provider.is_a?(AnthropicAdapter)
      # The one adapter without advanced_model/standard_model accessors;
      # model ids come from its own catalog
      { advanced: AnthropicAdapter::MODELS.first, standard: AnthropicAdapter::MODELS.last }
    else
      { advanced: provider.advanced_model, standard: provider.standard_model }
    end

    AiModelRouter.new(provider: provider, model_map: model_map)
  end
end
