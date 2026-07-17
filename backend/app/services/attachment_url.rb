class AttachmentUrl
  class << self
    def for(attachment)
      return nil unless attachment&.attached?

      Rails.application.routes.url_helpers.rails_blob_url(attachment, **url_options)
    end

    private

    def url_options
      uri = URI.parse(ENV.fetch('BACKEND_URL', 'http://localhost:3001'))
      { protocol: uri.scheme, host: uri.host, port: uri.port }
    end
  end
end
