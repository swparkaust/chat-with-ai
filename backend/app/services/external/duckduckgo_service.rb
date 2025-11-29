module External
  class DuckduckgoService
    def self.search(query, max_results: 5)
      ddg = DuckDuckGo::Search.new
      results = ddg.search(query)

      results.first(max_results).map do |result|
        {
          title: result.title,
          url: result.url,
          snippet: result.description
        }
      end
    rescue StandardError => e
      Rails.logger.error "DuckDuckGo search failed: #{e.message}"
      []
    end
  end
end
