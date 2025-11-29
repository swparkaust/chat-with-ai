module Persona
  module Tools
    class WebFetchTool < BaseTool
      def name
        "WebFetch"
      end

      def description
        "Fetch and read content from web pages"
      end

      def available_actions
        ['fetch']
      end

      def get_action_params(action)
        case action
        when 'fetch'
          { "url" => "string" }
        else
          {}
        end
      end

      def get_context
        fetches = get_data('fetch_history') || []
        return "No recent page fetches" if fetches.empty?

        recent = fetches.last(3).reverse
        recent.map { |f| "#{f['timestamp']}: #{f['url']}" }.join("\n")
      end

      def execute(params)
        url = params[:url]

        content = External::WebFetchService.fetch(url)

        if content
          save_to_history(url, content.length)
          content
        else
          "Failed to fetch content from #{url}"
        end
      end

      private

      def save_to_history(url, content_length)
        fetches = get_data('fetch_history') || []
        fetches << {
          'url' => url,
          'content_length' => content_length,
          'timestamp' => Time.current.to_s
        }

        fetches = fetches.last(20)
        set_data('fetch_history', fetches)
      end
    end
  end
end
