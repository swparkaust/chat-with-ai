module Persona
  module Tools
    class ToolExecutorService
      # Execute tool chain with conversation context
      #
      # @param season [Season] The active season
      # @param conversation [Conversation, nil] Optional conversation for context
      # @param recent_messages [Array<Message>] Recent messages for context (default: empty)
      # @param context_description [String] Description for logging (e.g., "after read-only")
      # @return [Array] Results from tool execution
      def self.execute(season:, conversation: nil, recent_messages: [], context_description: nil)
        tool_manager = ToolManager.new(season)
        provider = Ai::ProviderFactory.default
        system_context = Ai::SystemContextBuilder.new(season.persona_state, conversation).build

        recent_text = format_recent_messages(recent_messages, conversation)

        results = tool_manager.execute_tool_chain(provider, system_context, recent_text)

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
