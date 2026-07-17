module AiProviders
  class OllamaAdapter < Base
    DEFAULT_HOST = "http://localhost:11434".freeze
    REQUEST_TIMEOUT = 120 # seconds

    MODELS = {
      advanced: %w[qwen3:32b deepseek-r1:32b llama3.1:70b],
      standard: %w[qwen3:8b llama3.1:8b gemma3:12b]
    }.freeze

    def initialize(host: DEFAULT_HOST, advanced_model: nil, standard_model: nil)
      @host = host
      @advanced_model = advanced_model || detect_best_model(:advanced)
      @standard_model = standard_model || detect_best_model(:standard)
    end

    def complete(model:, system:, prompt:, max_tokens: 4096)
      uri = URI("#{@host}/api/chat")

      body = {
        model: model,
        messages: [
          { role: "system", content: system },
          { role: "user", content: prompt }
        ],
        think: false,
        stream: false,
        options: { num_predict: max_tokens }
      }

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 10
      http.read_timeout = REQUEST_TIMEOUT

      request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
      request.body = body.to_json
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error("Ollama returned #{response.code}: #{response.body.to_s[0..200]}")
        return AiResponse.new(text: nil, model: model, provider: provider_name)
      end

      data = JSON.parse(response.body)
      text = data.dig("message", "content")

      AiResponse.new(
        text: text,
        model: model,
        provider: provider_name
      )
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      Rails.logger.error("Ollama timeout: #{e.message}")
      AiResponse.new(text: nil, model: model, provider: provider_name)
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
      Rails.logger.error("Ollama connection failed: #{e.message}")
      AiResponse.new(text: nil, model: model, provider: provider_name)
    rescue JSON::ParserError => e
      Rails.logger.error("Ollama returned non-JSON response: #{e.message}")
      AiResponse.new(text: nil, model: model, provider: provider_name)
    end

    def available_models
      uri = URI("#{@host}/api/tags")
      response = Net::HTTP.get_response(uri)
      data = JSON.parse(response.body)
      data.fetch("models", []).map { |m| m["name"] }
    rescue StandardError
      []
    end

    def provider_name
      "ollama"
    end

    def advanced_model
      @advanced_model
    end

    def standard_model
      @standard_model
    end

    def healthy?
      uri = URI("#{@host}/api/tags")
      response = Net::HTTP.get_response(uri)
      response.is_a?(Net::HTTPSuccess)
    rescue StandardError
      false
    end

    private

    def detect_best_model(tier)
      installed = available_models
      candidates = MODELS.fetch(tier)
      candidates.find { |m| installed.any? { |i| i.start_with?(m.split(":").first) } } || candidates.first
    end
  end
end
