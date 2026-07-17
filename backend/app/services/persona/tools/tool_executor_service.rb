module Persona
  module Tools
    class ToolExecutorService
      # recent_messages defaults to the conversation's own recent messages;
      # callers holding a memoized router (AiRouterConcern jobs) inject it so
      # one logical run never spans two provider builds.
      # The nil-sentinel is load-bearing: exceptions raised while evaluating
      # a kwarg DEFAULT escape the method-level rescue, so the fallback build
      # must happen in the body where "tools never break callers" holds.
      # triggers: pass when the caller already ran a trigger sweep — sweeps
      # consume one-shot triggers (ReminderTool persists completion), so
      # letting the chain re-sweep would find nothing and the triggers would
      # never reach the persona.
      def self.execute(season:, conversation: nil, recent_messages: nil, context_description: nil, router: nil, triggers: nil)
        tool_manager = ToolManager.new(season)
        router ||= AiProviders.build_router
        system_context = Ai::SystemContextBuilder.new(season.persona_state, conversation).build

        recent_messages ||= conversation ? conversation.recent_messages(15) : []
        recent_text = format_recent_messages(recent_messages, conversation)

        results = tool_manager.execute_tool_chain(router, system_context, recent_text, triggers: triggers)

        log_results(results, conversation, context_description) if results.any?

        results
      rescue StandardError => e
        Rails.logger.error "Tool execution failed#{context_description ? " #{context_description}" : ''}: #{e.message}"
        []
      end

      private_class_method def self.format_recent_messages(messages, conversation)
        return '' if messages.blank? || conversation.nil?

        user_identifier = conversation.user.identifier
        Messaging::ConversationHistoryFormatter.format(
          messages,
          user_identifier: user_identifier
        )
      end

      private_class_method def self.log_results(results, conversation, context_description)
        base_message = "Executed #{results.count} tool action#{'s' if results.count != 1}"

        if conversation
          base_message += " for conversation #{conversation.id}"
        end

        if context_description
          base_message += " #{context_description}"
        end

        Rails.logger.info base_message
      end
    end
  end
end
