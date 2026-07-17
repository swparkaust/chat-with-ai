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
        memos = items('memos')
        return "No memos" if memos.empty?

        recent = memos.last(5).reverse
        recent.map { |m| format_item_line(m, "#{m['created_at']}: #{m['content']} [#{Array(m['tags']).join(', ')}]") }.join("\n")
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
        add_item('memos',
          'content' => params[:content],
          'tags' => params[:tags] || []
        )
        "Memo added"
      end

      def remove_memo(id)
        remove_item('memos', id)
        "Memo removed"
      end

      def update_memo(params)
        memo = update_item('memos', params[:id]) do |m|
          m['content'] = params[:content] if params[:content]
          m['tags'] = params[:tags] if params[:tags]
        end

        memo ? "Memo updated" : "Memo not found"
      end

      def search_memos(query)
        results = items('memos').select do |m|
          m['content'].include?(query) || (m['tags'] & [query]).any?
        end

        results.map { |m| format_item_line(m, m['content']) }.join("\n")
      end

      def list_memos
        items('memos').map { |m| format_item_line(m, "#{m['created_at']}: #{m['content']}") }.join("\n")
      end
    end
  end
end
