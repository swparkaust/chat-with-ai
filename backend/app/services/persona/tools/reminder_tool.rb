module Persona
  module Tools
    class ReminderTool < BaseTool
      def name
        "Reminder"
      end

      def description
        "Set one-time and recurring reminders"
      end

      def available_actions
        ['add', 'remove', 'update', 'enable', 'disable', 'list']
      end

      def get_action_params(action)
        case action
        when 'add'
          { "content" => "string", "datetime" => "ISO datetime", "recurring?" => "boolean", "frequency?" => "daily|weekly|monthly" }
        when 'remove'
          { "id" => "string" }
        when 'update'
          { "id" => "string", "content?" => "string", "datetime?" => "ISO datetime", "recurring?" => "boolean", "frequency?" => "daily|weekly|monthly" }
        when 'enable'
          { "id" => "string" }
        when 'disable'
          { "id" => "string" }
        when 'list'
          {}
        else
          {}
        end
      end

      def get_context
        reminders = get_data('reminders') || []
        active = reminders.select { |r| !r['completed'] }

        return "No active reminders" if active.empty?

        active.first(5).map do |r|
          recur = r['recurring'] ? " (#{r['frequency']})" : ""
          "#{r['datetime']}: #{r['content']}#{recur}"
        end.join("\n")
      end

      def execute(params)
        action = params[:action]

        case action
        when 'add'
          add_reminder(params)
        when 'remove'
          remove_reminder(params[:id])
        when 'update'
          update_reminder(params)
        when 'enable'
          enable_reminder(params[:id])
        when 'disable'
          disable_reminder(params[:id])
        when 'complete'
          complete_reminder(params[:id])
        when 'list'
          list_reminders
        else
          "Unknown action"
        end
      end

      def check_triggers(current_time)
        reminders = get_data('reminders') || []
        triggers = []

        reminders.each do |reminder|
          next if reminder['completed']

          reminder_time = Time.parse(reminder['datetime'])

          if current_time >= reminder_time
            triggers << "Reminder: #{reminder['content']}"

            if reminder['recurring']
              update_recurring_reminder(reminder)
            else
              reminder['completed'] = true
            end
          end
        end

        set_data('reminders', reminders) if triggers.any?
        triggers
      end

      private

      def add_reminder(params)
        reminders = get_data('reminders') || []
        reminders << {
          'id' => SecureRandom.uuid,
          'content' => params[:content],
          'datetime' => params[:datetime],
          'recurring' => params[:recurring] || false,
          'frequency' => params[:frequency], # daily, weekly, monthly
          'completed' => false,
          'created_at' => Time.current.to_s
        }
        set_data('reminders', reminders)
        "Reminder added"
      end

      def remove_reminder(id)
        reminders = get_data('reminders') || []
        reminders.reject! { |r| r['id'] == id }
        set_data('reminders', reminders)
        "Reminder removed"
      end

      def update_reminder(params)
        reminders = get_data('reminders') || []
        reminder = reminders.find { |r| r['id'] == params[:id] }

        return "Reminder not found" unless reminder

        reminder['content'] = params[:content] if params[:content]
        reminder['datetime'] = params[:datetime] if params[:datetime]
        reminder['recurring'] = params[:recurring] if params.key?(:recurring)
        reminder['frequency'] = params[:frequency] if params[:frequency]

        set_data('reminders', reminders)
        "Reminder updated"
      end

      def enable_reminder(id)
        reminders = get_data('reminders') || []
        reminder = reminders.find { |r| r['id'] == id }

        return "Reminder not found" unless reminder

        reminder['completed'] = false
        set_data('reminders', reminders)
        "Reminder enabled"
      end

      def disable_reminder(id)
        reminders = get_data('reminders') || []
        reminder = reminders.find { |r| r['id'] == id }

        return "Reminder not found" unless reminder

        reminder['completed'] = true
        set_data('reminders', reminders)
        "Reminder disabled"
      end

      def complete_reminder(id)
        reminders = get_data('reminders') || []
        reminder = reminders.find { |r| r['id'] == id }
        reminder['completed'] = true if reminder
        set_data('reminders', reminders)
        "Reminder completed"
      end

      def list_reminders
        reminders = get_data('reminders') || []
        reminders.map { |r| "#{r['datetime']}: #{r['content']}" }.join("\n")
      end

      def update_recurring_reminder(reminder)
        current_time = Time.parse(reminder['datetime'])
        next_time = case reminder['frequency']
        when 'daily'
          current_time + 1.day
        when 'weekly'
          current_time + 1.week
        when 'monthly'
          current_time + 1.month
        else
          return
        end

        reminder['datetime'] = next_time.to_s
      end
    end
  end
end
