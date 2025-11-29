module Persona
  module Tools
    class WebSearchTool < BaseTool
      def name
        "WebSearch"
      end

      def description
        "Search the web using DuckDuckGo"
      end

      def available_actions
        ['search']
      end

      def get_action_params(action)
        case action
        when 'search'
          { "query" => "string", "max_results?" => "int (default 5)" }
        else
          {}
        end
      end

      def get_context
        searches = get_data('search_history') || []
        return "No recent searches" if searches.empty?

        recent = searches.last(3).reverse
        recent.map { |s| "#{s['timestamp']}: #{s['query']}" }.join("\n")
      end

      def execute(params)
        query = params[:query]
        max_results = params[:max_results] || 5

        results = External::DuckduckgoService.search(query, max_results: max_results)

        save_to_history(query, results)

        format_results(results)
      end

      private

      def save_to_history(query, results)
        searches = get_data('search_history') || []
        searches << {
          'query' => query,
          'results_count' => results.length,
          'timestamp' => Time.current.to_s
        }

        searches = searches.last(20)
        set_data('search_history', searches)
      end

      def format_results(results)
        return "No results found" if results.empty?

        results.map.with_index(1) do |result, i|
          "#{i}. #{result[:title]}\n   #{result[:snippet]}\n   #{result[:url]}"
        end.join("\n\n")
      end
    end
  end
end
