module AiProviders
  class GeminiAdapter < Base
    MODELS = {
      advanced: %w[gemini-2.5-flash gemini-2.5-pro],
      standard: %w[gemini-2.5-flash gemini-2.5-flash-lite]
    }.freeze

    def initialize(api_key:, models: nil)
      @api_key = api_key
      @models = models
      @clients = {}
    end

    def complete(model:, system:, prompt:, max_tokens: 4096)
      # System text is prepended, most-stable-first, which preserves Gemini's
      # implicit prefix caching across calls sharing the same system block
      result = client_for(model).generate_content(
        {
          contents: { role: 'user', parts: { text: "#{system}\n\n#{prompt}" } },
          generationConfig: { maxOutputTokens: max_tokens }
        }
      )

      if result.dig('candidates', 0, 'finishReason') == 'SAFETY'
        log_error("Gemini blocked content by safety filters")
        return AiResponse.new(text: nil, model: model, provider: provider_name)
      end

      text = result.dig('candidates', 0, 'content', 'parts', 0, 'text')
      AiResponse.new(text: text, model: model, provider: provider_name)
    rescue StandardError => e
      log_error("Gemini API error: #{e.message}")
      AiResponse.new(text: nil, model: model, provider: provider_name)
    end

    def available_models
      @models ? @models.values.flatten : MODELS.values.flatten
    end

    def provider_name
      "gemini"
    end

    def advanced_model
      @models&.dig(:advanced) || MODELS[:advanced].first
    end

    def standard_model
      @models&.dig(:standard) || MODELS[:standard].first
    end

    private

    # The gemini gem binds the model at client construction, so clients are
    # memoized per model
    def client_for(model)
      @clients[model] ||= Gemini.new(
        credentials: {
          service: 'generative-language-api',
          api_key: @api_key
        },
        options: {
          model: model
        }
      )
    end

    def log_error(msg)
      defined?(Rails) ? Rails.logger.error(msg) : warn(msg)
    end
  end
end
