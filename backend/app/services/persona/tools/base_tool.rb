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

      def get_data(key = nil)
        return @tool_state.state_data if key.nil?
        @tool_state.get_state(key)
      end

      def set_data(key, value)
        @tool_state.set_state(key, value)
      end

      def update_data(hash)
        @tool_state.update_state(hash)
      end

      def check_triggers(current_time)
        []
      end
    end
  end
end
