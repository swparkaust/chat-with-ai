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
        events = items('events')
        return "일정 없음" if events.empty?

        future_events = events.select do |e|
          start_time = safe_parse_time(e['start_time'])
          start_time && start_time > Time.current
        end
        return "앞으로 예정된 일정 없음" if future_events.empty?

        future_events = future_events.sort_by { |e| e['start_time'] }.first(10)

        lines = ["예정된 일정 (#{future_events.size}개):"]
        future_events.each do |event|
          date_str = safe_parse_time(event['start_time']).strftime('%m/%d %H:%M')
          lines << "- #{format_item_line(event, "#{event['title']} at #{date_str}")}"
        end

        lines.join("\n")
      end

      def execute(params)
        action = params[:action]

        case action
        when 'add'
          add_event(params)
        when 'list'
          list_events
        when 'remove'
          delete_event(params[:id])
        when 'update'
          update_event(params)
        else
          "Unknown action: #{action}"
        end
      end

      def check_triggers(current_time)
        events = items('events')
        triggers = []

        events.each do |event|
          next if event['triggered']

          event_time = safe_parse_time(event['start_time'])
          next unless event_time

          time_until = event_time - current_time

          if time_until > 0 && time_until < 1.hour
            triggers << "Upcoming event: #{event['title']} at #{event['start_time']}"
            # Once per event by construction — a re-fire would wake every
            # conversation's decision loop again next sweep
            event['triggered'] = true
          end
        end

        # Non-atomic — see JsonbStateAccessor#set_state
        set_data('events', events) if triggers.any?
        triggers
      end

      private

      def add_event(params)
        return invalid_datetime_error(params[:start_time]) unless safe_parse_time(params[:start_time])

        event = add_item('events',
          'title' => params[:title],
          'start_time' => params[:start_time],
          'duration_minutes' => params[:duration_minutes] || 60,
          'location' => params[:location],
          'notes' => params[:notes]
        )
        "Event added: #{event['title']} [#{event['id']}]"
      end

      def update_event(params)
        return invalid_datetime_error(params[:start_time]) if params[:start_time] && !safe_parse_time(params[:start_time])

        event = update_item('events', params[:id]) do |e|
          e['title'] = params[:title] if params[:title]
          if params[:start_time]
            e['start_time'] = params[:start_time]
            # A rescheduled event deserves a fresh pre-event trigger
            e.delete('triggered')
          end
          e['duration_minutes'] = params[:duration_minutes] if params[:duration_minutes]
          e['location'] = params[:location] if params[:location]
          e['notes'] = params[:notes] if params[:notes]
        end

        return "Event not found: #{params[:id]}" unless event

        "Event updated: #{event['title']} [#{event['id']}]"
      end

      def list_events
        events = items('events')
        return "일정 없음" if events.empty?

        events.map do |e|
          date_str = safe_parse_time(e['start_time'])&.strftime('%m/%d %H:%M') || e['start_time'].inspect
          format_item_line(e, "#{date_str}: #{e['title']}")
        end.join("\n")
      end

      def delete_event(id)
        remove_item('events', id)
        "Event deleted: [#{id}]"
      end
    end
  end
end
