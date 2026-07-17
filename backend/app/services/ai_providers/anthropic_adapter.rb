module AiProviders
  class AnthropicAdapter < Base
    MODELS = %w[
      claude-opus-4-20250514
      claude-sonnet-4-20250514
    ].freeze

    def initialize(api_key:)
      @client = Anthropic::Client.new(api_key: api_key)
    end

    def complete(model:, system:, prompt:, max_tokens: 4096)
      response = @client.messages(
        model: model,
        max_tokens: max_tokens,
        system: system,
        messages: [ { role: "user", content: prompt } ]
      )

      text = response.dig("content", 0, "text") if response.is_a?(Hash)

      AiResponse.new(
        text: text,
        model: model,
        provider: provider_name
      )
    rescue StandardError => e
      Rails.logger.error("Anthropic API error: #{e.message}")
      AiResponse.new(text: nil, model: model, provider: provider_name)
    end

    def available_models
      MODELS
    end

    def provider_name
      "anthropic"
    end
  end
end
