module Persona
  module Tools
    class MemoTool < BaseTool
      def name
        "Memo"
      end

      def description
        "Quick notes with tags for easy retrieval"
      end

      def available_actions
        ['add', 'remove', 'update', 'search', 'list']
      end

      def get_action_params(action)
        case action
        when 'add'
          { "content" => "string", "tags?" => "list of strings" }
        when 'remove'
          { "id" => "string" }
        when 'update'
          { "id" => "string", "content?" => "string", "tags?" => "list of strings" }
        when 'search'
          { "query" => "string" }
        when 'list'
          {}
        else
          {}
        end
      end

      def get_context
        memos = get_data('memos') || []
        return "No memos" if memos.empty?

        recent = memos.last(5).reverse
        recent.map { |m| "#{m['created_at']}: #{m['content']} [#{m['tags'].join(', ')}]" }.join("\n")
      end

      def execute(params)
        action = params[:action]

        case action
        when 'add'
          add_memo(params)
        when 'remove'
          remove_memo(params[:id])
        when 'update'
          update_memo(params)
        when 'search'
          search_memos(params[:query])
        when 'list'
          list_memos
        else
          "Unknown action"
        end
      end

      private

      def add_memo(params)
        memos = get_data('memos') || []
        memos << {
          'id' => SecureRandom.uuid,
          'content' => params[:content],
          'tags' => params[:tags] || [],
          'created_at' => Time.current.to_s
        }
        set_data('memos', memos)
        "Memo added"
      end

      def remove_memo(id)
        memos = get_data('memos') || []
        memos.reject! { |m| m['id'] == id }
        set_data('memos', memos)
        "Memo removed"
      end

      def update_memo(params)
        memos = get_data('memos') || []
        memo = memos.find { |m| m['id'] == params[:id] }

        return "Memo not found" unless memo

        memo['content'] = params[:content] if params[:content]
        memo['tags'] = params[:tags] if params[:tags]

        set_data('memos', memos)
        "Memo updated"
      end

      def search_memos(query)
        memos = get_data('memos') || []
        results = memos.select do |m|
          m['content'].include?(query) || (m['tags'] & [query]).any?
        end

        results.map { |m| m['content'] }.join("\n")
      end

      def list_memos
        memos = get_data('memos') || []
        memos.map { |m| "#{m['created_at']}: #{m['content']}" }.join("\n")
      end
    end
  end
end
