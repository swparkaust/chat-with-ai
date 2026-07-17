module AiProviders
  class OpenaiAdapter < Base
    DEFAULT_HOST = "https://api.openai.com".freeze

    MODELS = {
      advanced: %w[gpt-4o o3],
      standard: %w[gpt-4o-mini gpt-4.1-mini]
    }.freeze

    def initialize(api_key:, base_url: nil, models: nil)
      @api_key = api_key
      @base_url = (base_url || ENV["OPENAI_BASE_URL"] || DEFAULT_HOST).chomp("/")
      @models = models
    end

    def complete(model:, system:, prompt:, max_tokens: 4096)
      uri = URI("#{@base_url}/v1/chat/completions")

      body = {
        model: model,
        messages: [
          { role: "system", content: system },
          { role: "user", content: prompt }
        ],
        max_tokens: max_tokens
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 120

      request = Net::HTTP::Post.new(uri.path, {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{@api_key}"
      })
      request.body = body.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        log_error("OpenAI adapter returned #{response.code}: #{response.body.to_s[0..200]}")
        return AiResponse.new(text: nil, model: model, provider: provider_name)
      end

      data = JSON.parse(response.body)
      text = data.dig("choices", 0, "message", "content")

      AiResponse.new(text: text, model: model, provider: provider_name)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      log_error("OpenAI adapter timeout: #{e.message}")
      AiResponse.new(text: nil, model: model, provider: provider_name)
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
      log_error("OpenAI adapter connection failed: #{e.message}")
      AiResponse.new(text: nil, model: model, provider: provider_name)
    rescue JSON::ParserError => e
      log_error("OpenAI adapter non-JSON response: #{e.message}")
      AiResponse.new(text: nil, model: model, provider: provider_name)
    end

    def available_models
      @models ? @models.values.flatten : MODELS.values.flatten
    end

    def provider_name
      "openai"
    end

    def advanced_model
      @models&.dig(:advanced) || MODELS[:advanced].first
    end

    def standard_model
      @models&.dig(:standard) || MODELS[:standard].first
    end

    private

    def log_error(msg)
      defined?(Rails) ? Rails.logger.error(msg) : warn(msg)
    end
  end
end
