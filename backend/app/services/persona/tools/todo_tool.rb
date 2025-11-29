module Persona
  module Tools
    class TodoTool < BaseTool
      def name
        "Todo"
      end

      def description
        "Task management with priorities and due dates"
      end

      def available_actions
        ['add', 'remove', 'update', 'complete', 'uncomplete', 'list']
      end

      def get_action_params(action)
        case action
        when 'add'
          { "content" => "string", "priority?" => "low|medium|high", "due_date?" => "ISO datetime" }
        when 'remove'
          { "id" => "string" }
        when 'update'
          { "id" => "string", "content?" => "string", "priority?" => "low|medium|high", "due_date?" => "ISO datetime" }
        when 'complete'
          { "id" => "string" }
        when 'uncomplete'
          { "id" => "string" }
        when 'list'
          {}
        else
          {}
        end
      end

      def get_context
        tasks = get_data('tasks') || []
        pending = tasks.select { |t| !t['completed'] }

        return "No pending tasks" if pending.empty?

        urgent = pending.select { |t| t['priority'] == 'high' }.first(3)
        regular = pending.select { |t| t['priority'] != 'high' }.first(2)

        (urgent + regular).map do |t|
          priority = t['priority'] == 'high' ? '[긴급] ' : ''
          due = t['due_date'] ? " (마감: #{t['due_date']})" : ''
          "#{priority}#{t['content']}#{due}"
        end.join("\n")
      end

      def execute(params)
        action = params[:action]

        case action
        when 'add'
          add_task(params)
        when 'remove'
          remove_task(params[:id])
        when 'update'
          update_task(params)
        when 'complete'
          complete_task(params[:id])
        when 'uncomplete'
          uncomplete_task(params[:id])
        when 'list'
          list_tasks
        else
          "Unknown action"
        end
      end

      def check_triggers(current_time)
        tasks = get_data('tasks') || []
        triggers = []

        tasks.each do |task|
          next if task['completed'] || !task['due_date']

          due_time = Time.parse(task['due_date'])
          time_until = due_time - current_time

          if time_until > 0 && time_until < 24.hours
            triggers << "Task due soon: #{task['content']}"
          elsif time_until < 0
            triggers << "Task overdue: #{task['content']}"
          end
        end

        triggers
      end

      private

      def add_task(params)
        tasks = get_data('tasks') || []
        tasks << {
          'id' => SecureRandom.uuid,
          'content' => params[:content],
          'priority' => params[:priority] || 'normal',
          'due_date' => params[:due_date],
          'completed' => false,
          'created_at' => Time.current.to_s
        }
        set_data('tasks', tasks)
        "Task added"
      end

      def remove_task(id)
        tasks = get_data('tasks') || []
        tasks.reject! { |t| t['id'] == id }
        set_data('tasks', tasks)
        "Task removed"
      end

      def update_task(params)
        tasks = get_data('tasks') || []
        task = tasks.find { |t| t['id'] == params[:id] }

        return "Task not found" unless task

        task['content'] = params[:content] if params[:content]
        task['priority'] = params[:priority] if params[:priority]
        task['due_date'] = params[:due_date] if params[:due_date]

        set_data('tasks', tasks)
        "Task updated"
      end

      def complete_task(id)
        tasks = get_data('tasks') || []
        task = tasks.find { |t| t['id'] == id }
        task['completed'] = true if task
        set_data('tasks', tasks)
        "Task completed"
      end

      def uncomplete_task(id)
        tasks = get_data('tasks') || []
        task = tasks.find { |t| t['id'] == id }

        return "Task not found" unless task

        task['completed'] = false
        set_data('tasks', tasks)
        "Task marked as incomplete"
      end

      def list_tasks
        tasks = get_data('tasks') || []
        tasks.select { |t| !t['completed'] }
             .map { |t| "#{t['content']} [#{t['priority']}]" }
             .join("\n")
      end
    end
  end
end
