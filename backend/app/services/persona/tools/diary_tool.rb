module Persona
  module Tools
    class DiaryTool < BaseTool
      def name
        "Diary"
      end

      def description
        "Emotional logging and daily reflections"
      end

      def available_actions
        ['add', 'remove', 'update', 'get_recent', 'read', 'list']
      end

      def get_action_params(action)
        case action
        when 'add'
          { "date" => "ISO datetime", "mood" => "string", "content" => "string", "tags?" => "list of strings" }
        when 'remove'
          { "id" => "string" }
        when 'update'
          { "id" => "string", "mood?" => "string", "content?" => "string", "tags?" => "list of strings" }
        when 'get_recent'
          { "days?" => "int" }
        when 'list'
          {}
        else
          {}
        end
      end

      def get_context
        entries = get_data('entries') || []
        return "No diary entries" if entries.empty?

        recent = entries.last(3).reverse
        recent.map do |e|
          date = Time.parse(e['date']).strftime('%Y-%m-%d')
          "#{date}: #{e['mood']} - #{e['content'][0..100]}"
        end.join("\n")
      end

      def execute(params)
        action = params[:action]

        case action
        when 'add'
          add_entry(params)
        when 'remove'
          remove_entry(params[:id])
        when 'update'
          update_entry(params)
        when 'get_recent'
          get_recent_entries(params[:days])
        when 'read'
          read_entries(params[:date])
        when 'list'
          list_entries
        else
          "Unknown action"
        end
      end

      private

      def add_entry(params)
        entries = get_data('entries') || []
        entries << {
          'id' => SecureRandom.uuid,
          'date' => params[:date] || Time.current.to_s,
          'mood' => params[:mood],
          'content' => params[:content],
          'tags' => params[:tags] || [],
          'created_at' => Time.current.to_s
        }
        set_data('entries', entries)
        "Diary entry added"
      end

      def remove_entry(id)
        entries = get_data('entries') || []
        entries.reject! { |e| e['id'] == id }
        set_data('entries', entries)
        "Diary entry removed"
      end

      def update_entry(params)
        entries = get_data('entries') || []
        entry = entries.find { |e| e['id'] == params[:id] }

        return "Diary entry not found" unless entry

        entry['mood'] = params[:mood] if params[:mood]
        entry['content'] = params[:content] if params[:content]
        entry['tags'] = params[:tags] if params[:tags]

        set_data('entries', entries)
        "Diary entry updated"
      end

      def get_recent_entries(days = nil)
        entries = get_data('entries') || []
        return "No entries" if entries.empty?

        days_count = (days || 7).to_i
        cutoff_date = Time.current - days_count.days

        recent = entries.select { |e| Time.parse(e['date']) >= cutoff_date }
        recent.map do |e|
          date = Time.parse(e['date']).strftime('%Y-%m-%d')
          "#{date}: #{e['mood']} - #{e['content'][0..100]}"
        end.join("\n")
      end

      def read_entries(date = nil)
        entries = get_data('entries') || []

        if date
          filtered = entries.select { |e| e['date'].start_with?(date) }
          filtered.map { |e| e['content'] }.join("\n")
        else
          entries.last(5).map { |e| e['content'] }.join("\n")
        end
      end

      def list_entries
        entries = get_data('entries') || []
        entries.map do |e|
          date = Time.parse(e['date']).strftime('%Y-%m-%d')
          "#{date}: #{e['mood']}"
        end.join("\n")
      end
    end
  end
end
