module Ai
  module Providers
    class GeminiProvider < Ai::BaseProvider
      def initialize(api_key: nil, model: nil)
        @api_key = api_key || ENV['GEMINI_API_KEY']
        @model = model || ENV.fetch('GEMINI_MODEL', 'gemini-2.5-flash')
        @client = nil
      end

      def generate_content(prompt, temperature: 1.0)
        ensure_client_initialized

        # Use non-streaming API for more reliable results
        result = @client.generate_content(
          {
            contents: { role: 'user', parts: { text: prompt } },
            generationConfig: {
              temperature: temperature,
              maxOutputTokens: 16384
            }
          }
        )

        text = result.dig('candidates', 0, 'content', 'parts', 0, 'text')

        if result.dig('candidates', 0, 'finishReason') == 'SAFETY'
          raise Ai::BaseProvider::ContentBlockedError, "Content was blocked by safety filters"
        end

        unless text
          Rails.logger.error "No text found in Gemini response: #{result.inspect}"
          raise Ai::BaseProvider::InvalidResponseError, "No text in response"
        end

        text
      rescue Ai::BaseProvider::Error
        raise
      rescue StandardError => e
        Rails.logger.error "Gemini API error: #{e.message}"
        raise Ai::BaseProvider::Error, "AI generation failed: #{e.message}"
      end

      def available?
        @api_key.present?
      end

      def provider_name
        "Google Gemini"
      end

      private

      def ensure_client_initialized
        return if @client

        unless available?
          raise Ai::BaseProvider::ConfigurationError,
                "Gemini API key not configured. Set GEMINI_API_KEY environment variable or configure via database."
        end

        @client = Gemini.new(
          credentials: {
            service: 'generative-language-api',
            api_key: @api_key
          },
          options: {
            model: @model
          }
        )
      end
    end
  end
end
