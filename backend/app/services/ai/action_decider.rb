module Ai
  class ActionDecider
    def initialize(router:)
      @router = router
    end

    def decide_action(conversation)
      persona_state = conversation.season.persona_state
      history = conversation.recent_messages(AppConstants::CONTEXT_MESSAGES_FOR_DECISION)
      unread_user_count = conversation.unread_user_messages.count
      unread_ai_count = conversation.unread_ai_messages.count

      # Explicitly false: a 30-420s poll cadence would flood the memory-
      # pruning signal — see the track_recall contract on the builder
      system_context = Ai::SystemContextBuilder.new(persona_state, conversation, track_recall: false).build
      decision_prompt = build_decision_prompt(history, unread_user_count, unread_ai_count, conversation.user)

      response = @router.call(task: :action_decision, system: system_context, prompt: decision_prompt)
      decision = Ai::JsonParsing.parse_object(response.text)

      # {} covers a blank response (failed or safety-blocked call) and any
      # non-object output — graceful wait fallback, never a retry cycle
      if decision.blank?
        return { action: 'wait', reason: '결정 실패', wait_seconds: AppConstants::AI_DECISION_FAILURE_RETRY_DELAY }
      end

      normalize_decision(decision.symbolize_keys)
    end

    private

    # Enforce at the AI-output boundary what the prompt only requests: an
    # unclamped wait of 0 would spin the decision loop into a hot AI-call
    # cycle, and an unbounded wait would park the persona's initiative
    # indefinitely — the hour ceiling is the product bound on idle checks
    def normalize_decision(decision)
      if decision[:action] == 'wait'
        # Float(..., exception: false) tolerates any junk type (Hash/Array/
        # nil from a quirky model), coercing to the minimum instead of
        # raising into the retry budget
        wait = Float(decision[:wait_seconds], exception: false) || 0
        decision[:wait_seconds] = wait.clamp(AppConstants::AI_WAIT_MIN_SECONDS, AppConstants::AI_WAIT_MAX_SECONDS)
      end
      decision
    end

    def build_decision_prompt(history, unread_user_count, unread_ai_count, user)
      history_text = Messaging::ConversationHistoryFormatter.format(
        history,
        user_identifier: user.identifier
      )

      <<~PROMPT
        Current conversation history:
        #{history_text.presence || "No messages yet"}

        Unread messages from the other person: #{unread_user_count}
        Your unread messages (messages you sent that they haven't read yet): #{unread_ai_count}

        Based on your personality, emotional state, and the conversation context, decide what to do:
        1. "respond" - Read and respond to unread messages now (ONLY if unread_count > 0)
        2. "read_only" - Read messages but don't respond (읽씹) (ONLY if unread_count > 0)
        3. "wait" - Wait before checking messages (specify how many seconds)
        4. "initiate" - Start a new conversation (ONLY if unread_count == 0)

        Before choosing "initiate", check the timestamps: how long since the last
        exchange, and how recently YOU last initiated. Don't initiate again after
        a short gap — repeated unprompted messages feel clingy. Only initiate
        more frequently if your personality genuinely dictates it.

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

        When you choose "wait", pick wait_seconds like a person deciding when
        to next glance at their phone:
        - Mid-conversation, or expecting a reply any moment: 10-120 seconds
        - A lull in an otherwise active exchange: a few minutes (120-600)
        - Conversation has gone quiet and nothing is pending: 15-60 minutes
          (900-#{AppConstants::AI_WAIT_MAX_SECONDS}), like putting your phone
          away and getting on with life
        - Asleep or clearly busy (check the current time in your context):
          lean toward the longest waits
        A new message from them wakes you IMMEDIATELY regardless of your
        chosen wait, so a long wait never delays your reply — it only spaces
        out how often you check in on your own.

        Respond with ONLY a JSON object:
        {
          "action": "respond" | "read_only" | "wait" | "initiate",
          "reason": "brief reason in Korean",
          "wait_seconds": #{AppConstants::AI_WAIT_MIN_SECONDS}-#{AppConstants::AI_WAIT_MAX_SECONDS} (only if action is wait)
        }
      PROMPT
    end

  end
end
