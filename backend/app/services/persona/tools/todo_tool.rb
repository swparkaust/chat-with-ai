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
        pending = items('tasks').reject { |t| t['completed'] }

        return "No pending tasks" if pending.empty?

        urgent = pending.select { |t| t['priority'] == 'high' }.first(3)
        regular = pending.select { |t| t['priority'] != 'high' }.first(2)

        (urgent + regular).map do |t|
          priority = t['priority'] == 'high' ? '[긴급] ' : ''
          due = t['due_date'] ? " (마감: #{t['due_date']})" : ''
          format_item_line(t, "#{priority}#{t['content']}#{due}")
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
        triggers = []

        items('tasks').each do |task|
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
        add_item('tasks',
          'content' => params[:content],
          'priority' => params[:priority] || 'normal',
          'due_date' => params[:due_date],
          'completed' => false
        )
        "Task added"
      end

      def remove_task(id)
        remove_item('tasks', id)
        "Task removed"
      end

      def update_task(params)
        task = update_item('tasks', params[:id]) do |t|
          t['content'] = params[:content] if params[:content]
          t['priority'] = params[:priority] if params[:priority]
          t['due_date'] = params[:due_date] if params[:due_date]
        end

        task ? "Task updated" : "Task not found"
      end

      def complete_task(id)
        task = update_item('tasks', id) { |t| t['completed'] = true }
        task ? "Task completed" : "Task not found"
      end

      def uncomplete_task(id)
        task = update_item('tasks', id) { |t| t['completed'] = false }
        task ? "Task marked as incomplete" : "Task not found"
      end

      def list_tasks
        items('tasks').reject { |t| t['completed'] }
                      .map { |t| format_item_line(t, "#{t['content']} [#{t['priority']}]") }
                      .join("\n")
      end
    end
  end
end
