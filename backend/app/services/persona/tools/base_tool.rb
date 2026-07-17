module Persona
  module Tools
    class BaseTool
      attr_reader :tool_state

      def initialize(tool_state)
        @tool_state = tool_state
      end

      def name
        raise NotImplementedError
      end

      def description
        raise NotImplementedError
      end

      def get_context
        raise NotImplementedError
      end

      def available_actions
        raise NotImplementedError
      end

      def get_action_params(action)
        raise NotImplementedError
      end

      def get_data(key)
        @tool_state.get_state(key)
      end

      def set_data(key, value)
        @tool_state.set_state(key, value)
      end

      def check_triggers(current_time)
        []
      end

      private

      # AI-written date strings reach parsers on every trigger sweep and
      # prompt build; a malformed value must skip its item, never raise
      def safe_parse_time(value)
        Time.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def safe_parse_date(value)
        Date.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      # Returned to the AI (via previous_results) so it can correct and retry
      def invalid_datetime_error(value)
        "Invalid datetime: #{value.inspect} — use ISO format (e.g. 2026-07-15T18:00:00+09:00)"
      end

      def invalid_date_error(value)
        "Invalid date: #{value.inspect} — use YYYY-MM-DD (e.g. 1998-07-15)"
      end

      def items(key)
        get_data(key) || []
      end

      def add_item(key, attrs)
        list = items(key)
        item = { 'id' => SecureRandom.uuid }.merge(attrs).merge('created_at' => Time.current.to_s)
        list << item
        set_data(key, list)
        item
      end

      def update_item(key, id)
        list = items(key)
        item = list.find { |i| i['id'] == id }
        return nil unless item

        yield item
        set_data(key, list)
        item
      end

      def remove_item(key, id)
        list = items(key)
        list.reject! { |item| item['id'] == id }
        set_data(key, list)
      end

      def append_history(key, entry, max: 20)
        history = items(key)
        history << entry.merge('timestamp' => Time.current.to_s)
        set_data(key, history.last(max))
      end

      def format_item_line(item, text)
        "[#{item['id']}] #{text}"
      end
    end
  end
end
