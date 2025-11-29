module Ai
  # Abstract base class for AI providers
  # All AI providers must implement the interface defined here
  #
  # This abstraction layer ensures business logic is completely decoupled
  # from any specific AI provider (Gemini, OpenAI, Claude, etc.)
  #
  # @example
  #   provider = Ai::ProviderFactory.create
  #   response = provider.generate_content("Hello", temperature: 0.7)
  #   json_data = provider.generate_json("Return JSON: {...}", temperature: 0.5)
  class BaseProvider
    # Provider-agnostic exception classes
    class Error < StandardError; end
    class ContentBlockedError < Error; end
    class RateLimitError < Error; end
    class InvalidResponseError < Error; end
    class ConfigurationError < Error; end

    # Generate content from a prompt
    # @param prompt [String] The prompt to send to the AI
    # @param temperature [Float] The temperature setting (0.0-2.0)
    # @return [String] The generated content
    # @raise [ContentBlockedError] If content is blocked by safety filters
    # @raise [RateLimitError] If rate limit is exceeded
    # @raise [InvalidResponseError] If response format is invalid
    # @raise [Error] For other provider errors
    def generate_content(prompt, temperature: 1.0)
      raise NotImplementedError, "#{self.class} must implement #generate_content"
    end

    # Generate structured JSON response
    # This is the preferred method for AI business logic that expects JSON
    # @param prompt [String] The prompt to send to the AI
    # @param temperature [Float] The temperature setting (0.0-2.0)
    # @return [Hash] Parsed JSON response (empty hash if parsing fails)
    # @raise [ContentBlockedError] If content is blocked by safety filters
    # @raise [RateLimitError] If rate limit is exceeded
    def generate_json(prompt, temperature: 1.0)
      response = generate_content(prompt, temperature: temperature)
      parse_json_response(response)
    end

    # Check if the provider is available/configured
    # @return [Boolean]
    def available?
      raise NotImplementedError, "#{self.class} must implement #available?"
    end

    # Get the provider name
    # @return [String]
    def provider_name
      raise NotImplementedError, "#{self.class} must implement #provider_name"
    end

    private

    # Parse JSON from AI response, handling markdown code blocks
    # @param response_text [String] Raw response from AI
    # @return [Hash] Parsed JSON (empty hash on failure)
    def parse_json_response(response_text)
      json_text = response_text.strip

      # Extract content between first opening brace and last closing brace
      # This handles cases where Gemini appends filenames after the closing backticks
      if json_text.include?('{') && json_text.include?('}')
        first_brace = json_text.index('{')
        last_brace = json_text.rindex('}')
        json_text = json_text[first_brace..last_brace] if first_brace && last_brace
      else
        json_text = json_text[7..-1] if json_text.start_with?('```json')
        json_text = json_text[0..-4] if json_text.end_with?('```')
      end

      json_text = json_text.strip

      JSON.parse(json_text)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse JSON response: #{e.message}"
      Rails.logger.error "Response text: #{response_text}"
      {}
    end
  end
end
