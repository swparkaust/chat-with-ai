module Ai
  class MessageGenerator
    def initialize(provider)
      @provider = provider
    end

    def generate_response(conversation, unread_messages)
      persona_state = conversation.season.persona_state
      history = conversation.recent_messages(AppConstants::CONTEXT_MESSAGES_FOR_RESPONSE)

      system_context = build_system_context(persona_state, conversation)
      response_prompt = build_response_prompt(system_context, history, unread_messages, conversation.user)

      response_text = @provider.generate_content(response_prompt, temperature: AppConstants::AI_TEMPERATURE_CREATIVE)

      fragments = response_text.strip.split("\n").map(&:strip).reject(&:blank?)

      Rails.logger.info "Generated #{fragments.length} response fragments"
      fragments
    end

    def initiate_conversation(conversation)
      persona_state = conversation.season.persona_state
      history = conversation.recent_messages(AppConstants::CONTEXT_MESSAGES_FOR_INITIATION)

      system_context = build_system_context(persona_state, conversation)
      initiation_prompt = build_initiation_prompt(system_context, history, conversation.user)

      response_text = @provider.generate_content(initiation_prompt, temperature: AppConstants::AI_TEMPERATURE_CREATIVE)

      fragments = response_text.strip.split("\n").map(&:strip).reject(&:blank?)

      Rails.logger.info "Generated #{fragments.length} initiation fragments"
      fragments
    end

    private

    def build_system_context(persona_state, conversation)
      Ai::SystemContextBuilder.new(persona_state, conversation).build
    end

    def build_response_prompt(system_context, history, unread_messages, user)
      history_text = format_history(history, user)
      unread_text = format_unread(unread_messages, user)

      <<~PROMPT
        #{system_context}

        Recent conversation history:
        #{history_text}

        NEW UNREAD MESSAGES FROM THE OTHER PERSON:
        #{unread_text}

        You just read all the unread messages above. Respond to them naturally as you would in Korean messaging.

        1. Fragment your response into multiple separate messages (like real Korean texting)
        2. Each fragment should be a separate line in your response
        3. Make fragments SHORT (3-15 characters each typically)
        4. Use natural Korean messaging rhythm
        5. Include reactions, expressions, then actual responses
        6. Remember: you're having a conversation thread, not replying to each message individually

        Respond with ONLY the message fragments, one per line, no JSON, no formatting.
        Each line will be sent as a separate message with realistic delays.
      PROMPT
    end

    def build_initiation_prompt(system_context, history, user)
      history_text = format_history(history, user)

      <<~PROMPT
        #{system_context}

        Conversation history:
        #{history_text.presence || "No previous messages"}

        You want to start a conversation or send a message to #{user.identifier}. This is your initiative.

        Think about:
        - What's on your mind right now
        - Your current emotional state
        - What you want to share or ask
        - Keep it natural and true to your personality

        1. Fragment your message into multiple separate messages
        2. Each fragment on a separate line
        3. Make it feel spontaneous and natural
        4. Use Korean messaging style

        Respond with ONLY the message fragments, one per line.
      PROMPT
    end

    def format_history(messages, user)
      Messaging::ConversationHistoryFormatter.format(
        messages,
        user_identifier: user.identifier
      )
    end

    def format_unread(messages, user)
      Messaging::ConversationHistoryFormatter.format(
        messages,
        user_identifier: user.identifier,
        include_read_status: false
      )
    end
  end
end
