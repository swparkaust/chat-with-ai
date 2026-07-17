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
        ['add', 'remove', 'update', 'enable', 'disable', 'complete', 'list']
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
        when 'disable', 'complete'
          { "id" => "string" }
        when 'list'
          {}
        else
          {}
        end
      end

      # Fired reminders stay visible this long: the trigger sweep wakes
      # conversations AFTER consuming them, and a decision that can't see
      # why it was woken can't act on it. Must exceed worst-case revival
      # latency (AiDecisionJob::HEARTBEAT_TTL + one hourly sweep + decision
      # latency) — retune alongside those constants.
      RECENT_FIRE_WINDOW = 2.hours
      VALID_FREQUENCIES = %w[daily weekly monthly].freeze

      def get_context
        reminders = items('reminders')
        active = reminders.reject { |r| r['completed'] }
        just_fired = reminders.filter_map do |r|
          fired_at = recently_fired_at(r)
          [r, fired_at] if fired_at
        end

        return "No active reminders" if active.empty? && just_fired.empty?

        lines = active.first(5).map do |r|
          recur = r['recurring'] ? " (#{r['frequency']})" : ""
          format_item_line(r, "#{r['datetime']}: #{r['content']}#{recur}")
        end
        lines += just_fired.first(3).map do |(r, fired_at)|
          format_item_line(r, "#{fired_at}: #{r['content']} (just fired — act on it now if it calls for one)")
        end
        lines.join("\n")
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
        when 'disable', 'complete'
          disable_reminder(params[:id])
        when 'list'
          list_reminders
        else
          "Unknown action"
        end
      end

      def check_triggers(current_time)
        reminders = items('reminders')
        triggers = []

        reminders.each do |reminder|
          next if reminder['completed']

          # Skip, never raise on, unparseable legacy data — write-time
          # validation guards new items only
          reminder_time = safe_parse_time(reminder['datetime'])
          next unless reminder_time

          if current_time >= reminder_time
            triggers << "Reminder: #{reminder['content']}"

            # Both branches stamp WHEN the firing happened, keeping it
            # visible to woken decisions (RECENT_FIRE_WINDOW on get_context)
            # after datetime has advanced or the item completed
            if reminder['recurring']
              advance_recurring_reminder(reminder, current_time)
              reminder['last_fired_at'] = current_time.iso8601 unless reminder['completed']
            else
              reminder['completed'] = true
              reminder['completed_at'] = current_time.iso8601
            end
          end
        end

        set_data('reminders', reminders) if triggers.any?
        triggers
      end

      private

      def add_reminder(params)
        return invalid_datetime_error(params[:datetime]) unless safe_parse_time(params[:datetime])
        if params[:recurring] && !VALID_FREQUENCIES.include?(params[:frequency])
          return "Invalid frequency: #{params[:frequency].inspect} — recurring reminders need daily, weekly or monthly"
        end

        add_item('reminders',
          'content' => params[:content],
          'datetime' => params[:datetime],
          'recurring' => params[:recurring] || false,
          'frequency' => params[:frequency],
          'completed' => false
        )
        "Reminder added"
      end

      def remove_reminder(id)
        remove_item('reminders', id)
        "Reminder removed"
      end

      def update_reminder(params)
        return invalid_datetime_error(params[:datetime]) if params[:datetime] && !safe_parse_time(params[:datetime])
        if params[:frequency] && !VALID_FREQUENCIES.include?(params[:frequency])
          return "Invalid frequency: #{params[:frequency].inspect} — use daily, weekly or monthly"
        end

        existing = items('reminders').find { |r| r['id'] == params[:id] }
        return "Reminder not found" unless existing

        # Validate the MERGED result: recurring without a valid frequency
        # only surfaces at fire time (quarantine), with no feedback loop to
        # the AI that wrote it — write time is where it can self-correct
        will_recur = params.key?(:recurring) ? params[:recurring] : existing['recurring']
        merged_frequency = params[:frequency] || existing['frequency']
        if will_recur && !VALID_FREQUENCIES.include?(merged_frequency)
          return "Recurring reminders need a frequency — daily, weekly or monthly"
        end

        reminder = update_item('reminders', params[:id]) do |r|
          r['content'] = params[:content] if params[:content]
          r['datetime'] = params[:datetime] if params[:datetime]
          r['recurring'] = params[:recurring] if params.key?(:recurring)
          r['frequency'] = params[:frequency] if params[:frequency]
        end

        reminder ? "Reminder updated" : "Reminder not found"
      end

      def enable_reminder(id)
        reminder = update_item('reminders', id) { |r| r['completed'] = false }
        reminder ? "Reminder enabled" : "Reminder not found"
      end

      def disable_reminder(id)
        reminder = update_item('reminders', id) { |r| r['completed'] = true }
        reminder ? "Reminder disabled" : "Reminder not found"
      end

      def list_reminders
        items('reminders').map { |r| format_item_line(r, "#{r['datetime']}: #{r['content']}") }.join("\n")
      end

      # The firing timestamp (one-shot completion or recurring last fire)
      # if recent enough to still explain a trigger wake, else nil
      def recently_fired_at(reminder)
        fired_at = reminder['completed'] ? reminder['completed_at'] : reminder['last_fired_at']
        return nil unless fired_at

        time = safe_parse_time(fired_at)
        time && time > RECENT_FIRE_WINDOW.ago ? fired_at : nil
      end

      def advance_recurring_reminder(reminder, current_time)
        step = case reminder['frequency']
               when 'daily' then 1.day
               when 'weekly' then 1.week
               when 'monthly' then 1.month
               end

        unless step
          # An unadvanceable reminder would re-fire every sweep forever.
          # Completing it stops that and surfaces it in the just-fired
          # window, where the persona can notice and fix it.
          Rails.logger.warn "ReminderTool: quarantining recurring reminder #{reminder['id']} with invalid frequency #{reminder['frequency'].inspect}"
          reminder['completed'] = true
          reminder['completed_at'] = current_time.iso8601
          return
        end

        # Advance past NOW, not one step: a backlogged reminder must fire
        # once, not once per sweep until its datetime catches up
        next_time = safe_parse_time(reminder['datetime']) || current_time
        next_time += step while next_time <= current_time
        reminder['datetime'] = next_time.to_s
      end
    end
  end
end
