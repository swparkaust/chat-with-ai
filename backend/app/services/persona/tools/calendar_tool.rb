module Persona
  module Tools
    class CalendarTool < BaseTool
      def name
        "Calendar"
      end

      def description
        "Manage schedules, appointments, and commitments. Events here affect your availability and mood."
      end

      def available_actions
        ['add', 'remove', 'update', 'list']
      end

      def get_action_params(action)
        case action
        when 'add'
          { 'title' => 'string', 'start_time' => 'ISO datetime', 'duration_minutes' => 'int', 'location?' => 'string', 'notes?' => 'string' }
        when 'remove'
          { 'id' => 'string' }
        when 'update'
          { 'id' => 'string', 'title?' => 'string', 'start_time?' => 'ISO datetime', 'duration_minutes?' => 'int', 'location?' => 'string', 'notes?' => 'string' }
        when 'list'
          {}
        else
          {}
        end
      end

      def get_context
        events = get_data('events') || []
        return "일정 없음" if events.empty?

        future_events = events.select { |e| Time.parse(e['start_time']) > Time.current }
        return "앞으로 예정된 일정 없음" if future_events.empty?

        future_events = future_events.sort_by { |e| e['start_time'] }.first(10)

        lines = ["예정된 일정 (#{future_events.size}개):"]
        future_events.each do |event|
          date_str = Time.parse(event['start_time']).strftime('%m/%d %H:%M')
          lines << "- [#{event['id']}] #{event['title']} at #{date_str}"
        end

        lines.join("\n")
      end

      def execute(params)
        action = params[:action] || params['action']

        case action
        when 'add'
          add_event(params)
        when 'list'
          list_events
        when 'remove'
          delete_event(params[:id] || params['id'])
        when 'update'
          update_event(params)
        else
          "Unknown action: #{action}"
        end
      end

      def check_triggers(current_time)
        events = get_data('events') || []
        triggers = []

        events.each do |event|
          event_time = Time.parse(event['start_time'])
          time_until = event_time - current_time

          if time_until > 0 && time_until < 1.hour
            triggers << "Upcoming event: #{event['title']} at #{event['start_time']}"
          end
        end

        triggers
      end

      private

      def add_event(params)
        events = get_data('events') || []
        event_id = SecureRandom.uuid
        events << {
          'id' => event_id,
          'title' => params[:title] || params['title'],
          'start_time' => params[:start_time] || params['start_time'],
          'duration_minutes' => params[:duration_minutes] || params['duration_minutes'] || 60,
          'location' => params[:location] || params['location'],
          'notes' => params[:notes] || params['notes'],
          'created_at' => Time.current.to_s
        }
        set_data('events', events)
        "Event added: #{params[:title] || params['title']} [#{event_id}]"
      end

      def update_event(params)
        events = get_data('events') || []
        event_id = params[:id] || params['id']
        event = events.find { |e| e['id'] == event_id }

        return "Event not found: #{event_id}" unless event

        event['title'] = params[:title] || params['title'] if params[:title] || params['title']
        event['start_time'] = params[:start_time] || params['start_time'] if params[:start_time] || params['start_time']
        event['duration_minutes'] = params[:duration_minutes] || params['duration_minutes'] if params[:duration_minutes] || params['duration_minutes']
        event['location'] = params[:location] || params['location'] if params[:location] || params['location']
        event['notes'] = params[:notes] || params['notes'] if params[:notes] || params['notes']

        set_data('events', events)
        "Event updated: #{event['title']} [#{event_id}]"
      end

      def list_events
        events = get_data('events') || []
        return "일정 없음" if events.empty?

        events.map { |e| "[#{e['id']}] #{Time.parse(e['start_time']).strftime('%m/%d %H:%M')}: #{e['title']}" }.join("\n")
      end

      def delete_event(id)
        events = get_data('events') || []
        events.reject! { |e| e['id'] == id }
        set_data('events', events)
        "Event deleted: [#{id}]"
      end
    end
  end
end
