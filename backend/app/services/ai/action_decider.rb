module Ai
  class ActionDecider
    def initialize(provider)
      @provider = provider
    end

    def decide_action(conversation)
      persona_state = conversation.season.persona_state
      history = conversation.recent_messages(AppConstants::CONTEXT_MESSAGES_FOR_DECISION)
      unread_user_count = conversation.unread_user_messages.count
      unread_ai_count = conversation.unread_ai_messages.count

      system_context = Ai::SystemContextBuilder.new(persona_state, conversation).build
      decision_prompt = build_decision_prompt(system_context, history, unread_user_count, unread_ai_count, conversation.user)

      decision = @provider.generate_json(decision_prompt, temperature: AppConstants::AI_TEMPERATURE_CREATIVE)

      return { action: 'wait', reason: '결정 실패', wait_seconds: AppConstants::AI_DECISION_FAILURE_RETRY_DELAY } if decision.blank?

      decision.symbolize_keys
    rescue Ai::BaseProvider::ContentBlockedError => e
      Rails.logger.warn "Action decision blocked: #{e.message}"
      { action: 'wait', reason: '콘텐츠 차단됨', wait_seconds: AppConstants::AI_DECISION_BLOCKED_RETRY_DELAY }
    rescue Ai::BaseProvider::Error => e
      Rails.logger.warn "Action decision failed: #{e.message}"
      { action: 'wait', reason: '결정 실패', wait_seconds: AppConstants::AI_DECISION_FAILURE_RETRY_DELAY }
    end

    private

    def build_decision_prompt(system_context, history, unread_user_count, unread_ai_count, user)
      history_text = Messaging::ConversationHistoryFormatter.format(
        history,
        user_identifier: user.identifier
      )

      <<~PROMPT
        #{system_context}

        Current conversation history:
        #{history_text.presence || "No messages yet"}

        Unread messages from the other person: #{unread_user_count}
        Your unread messages (messages you sent that they haven't read yet): #{unread_ai_count}

        Based on your personality, emotional state, and the conversation context, decide what to do:
        1. "respond" - Read and respond to unread messages now (ONLY if unread_count > 0)
        2. "read_only" - Read messages but don't respond (읽씹) (ONLY if unread_count > 0)
        3. "wait" - Wait before checking messages (specify how many seconds)
        4. "initiate" - Start a new conversation (ONLY if unread_count == 0)

        Consider:
        - Your current emotional state
        - Your personality traits
        - How clingy or independent you are
        - Whether you're busy or free
        - The conversation flow
        - Whether you WANT to talk right now

        IMPORTANT - Understand the difference between two scenarios:
        1. 안읽씹 (Unread): unread_ai_count > 0 means they haven't even opened the chat
           - Less personal/emotional: They might be busy, sleeping, phone off, or away
           - Natural interpretation: "They haven't seen it yet"
           - Response: Wait patiently (unless very clingy personality), don't spam messages

        2. 읽씹 (Read but ignored): unread_ai_count == 0 AND they haven't replied
           - MORE personal/emotional: They READ your messages but chose not to respond
           - Possible meanings: Intentionally ignoring, upset/angry, need space, lost interest, being passive-aggressive
           - Your reaction depends on:
             * Personality: Anxious attachment = worried/hurt, secure = give space, avoidant = relieved
             * Context: After argument = probably upset, casual chat = might reply later
             * Relationship: Close = more hurt, distant = less affected
           - Behavior options: Give space, feel hurt/worried, initiate later if appropriate, or do read_only yourself as retaliation

        - You can read messages without responding (read_only) when: upset, busy, not interested, need time to think, being passive-aggressive, etc.

        Respond with ONLY a JSON object:
        {
          "action": "respond" | "read_only" | "wait" | "initiate",
          "reason": "brief reason in Korean",
          "wait_seconds": 10-300 (only if action is wait)
        }
      PROMPT
    end

  end
end
