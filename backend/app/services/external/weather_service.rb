module External
  class WeatherService
    include HTTParty
    base_uri 'https://wttr.in'

    CACHE_TTL = 3600

    def self.get_weather(location = 'Seoul')
      cache_key = "weather:#{location}"

      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        fetch_weather(location)
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to fetch weather: #{e.message}"
      'Weather unavailable'
    end

    def self.fetch_weather(location)
      response = get(
        "/#{location}",
        query: { format: '%C+%t' },
        timeout: 3
      )

      if response.success?
        response.body.strip
      else
        'Weather unavailable'
      end
    end
    private_class_method :fetch_weather
  end
end
