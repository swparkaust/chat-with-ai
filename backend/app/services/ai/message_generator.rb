module Ai
  class MessageGenerator
    def initialize(router:)
      @router = router
    end

    def generate_response(conversation, unread_messages)
      history = conversation.recent_messages(AppConstants::CONTEXT_MESSAGES_FOR_RESPONSE)

      system_context = build_system_context(conversation.season.persona_state, conversation)
      prompt = build_response_prompt(history, unread_messages, conversation.user)

      generate_fragments(:message_generation, system_context, prompt, 'response')
    end

    def initiate_conversation(conversation)
      history = conversation.recent_messages(AppConstants::CONTEXT_MESSAGES_FOR_INITIATION)

      system_context = build_system_context(conversation.season.persona_state, conversation)
      prompt = build_initiation_prompt(history, conversation.user)

      generate_fragments(:conversation_initiation, system_context, prompt, 'initiation')
    end

    def generate_farewell(conversation)
      system_context = build_system_context(conversation.season.persona_state, conversation)
      prompt = build_farewell_prompt(conversation.user, conversation.season)

      generate_fragments(:farewell_generation, system_context, prompt, 'farewell')
    end

    private

    def generate_fragments(task, system_context, prompt, label)
      response = @router.call(task: task, system: system_context, prompt: prompt)
      fragments = parse_fragments(response.text)

      # Adapters never raise (blank text = failed or safety-blocked call);
      # generation cannot proceed without output, so raise here to engage
      # the bounded retries instead of an empty chain silently completing
      # (and, for farewells, looping)
      raise Ai::GenerationError, "empty #{label} response" if fragments.empty?

      Rails.logger.info "Generated #{fragments.length} #{label} fragments"
      fragments
    end

    def parse_fragments(text)
      return [] if text.blank?

      text.strip.split("\n").map(&:strip).reject(&:blank?)
    end

    def build_system_context(persona_state, conversation)
      Ai::SystemContextBuilder.new(persona_state, conversation, track_recall: true).build
    end

    def build_response_prompt(history, unread_messages, user)
      history_text = format_history(history, user)
      unread_text = format_unread(unread_messages, user)

      <<~PROMPT
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

    def build_initiation_prompt(history, user)
      history_text = format_history(history, user)

      <<~PROMPT
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

    def build_farewell_prompt(user, season)
      remaining_days = (season.rotation_date.to_date - Date.current).to_i.clamp(1, 365)

      <<~PROMPT
        You need to gently let #{user.identifier} know that you'll be leaving soon (in about #{remaining_days} days).

        IMPORTANT:
        - Do NOT reveal you are an AI
        - Make it natural and personal (e.g., moving away, life changes, etc.)
        - Be emotional and authentic to your personality
        - Give them time to say goodbye
        - Fragment your message naturally

        This is a personal goodbye message. Write it naturally in Korean messaging style, one fragment per line.
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
