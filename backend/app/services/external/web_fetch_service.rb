module External
  class WebFetchService
    include HTTParty

    USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'

    def self.fetch(url)
      response = get(
        url,
        headers: {
          'User-Agent' => USER_AGENT,
          'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
        },
        timeout: 10,
        follow_redirects: true
      )

      return nil unless response.success?

      doc = Nokogiri::HTML(response.body)

      doc.css('script, style, nav, header, footer').remove

      text = doc.css('body').text
      text.gsub(/\s+/, ' ').strip[0..5000]
    rescue StandardError => e
      Rails.logger.error "Web fetch failed for #{url}: #{e.message}"
      nil
    end
  end
end
