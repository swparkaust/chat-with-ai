module Ai
  class StateEvolver
    def initialize(router:)
      @router = router
    end

    def evolve_from_conversation(conversation, recent_messages)
      persona_state = conversation.season.persona_state

      system_context = Ai::SystemContextBuilder.new(persona_state, conversation).build
      evolution_prompt = build_evolution_prompt(recent_messages, conversation.user)

      response = @router.call(task: :state_evolution, system: system_context, prompt: evolution_prompt)

      if response.text.blank?
        Rails.logger.error "State evolution failed: blank AI response"
        return false
      end

      updates = Ai::JsonParsing.parse_object(response.text)
      Ai::JsonParsing.coerce_string_array!(updates, 'emotions')

      apply_updates(persona_state, updates)

      true
    rescue StandardError => e
      Rails.logger.error "State evolution failed: #{e.message}"
      false
    end

    private

    def build_evolution_prompt(messages, user)
      user_identifier = user.identifier

      history_text = Messaging::ConversationHistoryFormatter.format(
        messages,
        user_identifier: user_identifier
      )

      <<~PROMPT
        #{build_prompt_header(history_text)}

        #{build_critical_guidelines}

        #{build_json_schema}

        #{build_memory_guidelines(user_identifier)}
      PROMPT
    end

    def build_prompt_header(history_text)
      <<~HEADER.chomp
        Recent conversation:
        #{history_text}

        Based on this conversation, update the persona's state naturally. How has their context, emotion, memories, or life situation changed?
      HEADER
    end

    def build_critical_guidelines
      <<~GUIDELINES.chomp
        CRITICAL: Maintain strict separation between context and emotion:
        - CONTEXT = OBJECTIVE FACTS ONLY (what is happening, where they are, what they're doing, time of day, schedule, environment)
        - EMOTION = SUBJECTIVE FEELINGS ONLY (how they feel, their mood, emotional reactions)

        ALL LIFE SITUATION FIELDS ARE OPTIONAL - only include them if a significant life change occurred based on the conversation (got a job, moved, graduated, started dating, etc.). Most conversations won't change these.

        #{Ai::PersonaFields.critical_data_guidelines}
      GUIDELINES
    end

    def build_json_schema
      <<~SCHEMA.chomp
        Respond with ONLY a JSON object:
        {
          "context": "updated current situation in Korean - OBJECTIVE FACTS ONLY, no emotional words or judgments",
          "emotions": ["keyword1", "keyword2"],  // 2-5 emotion keywords
          "emotion_description": "updated emotional state in Korean - SUBJECTIVE FEELINGS ONLY",
          "status_message": "updated status message in Korean - typically very short (2-15 characters preferred, like 'zzz', '바빠', 'ㅠㅠ', '...', 'ㅋㅋ', '힘들다'), but can be longer if expressing something specific. Most Koreans use brief status messages." (OPTIONAL - only if mood/situation significantly changed),
        #{Ai::PersonaFields.schema_lines}
          "new_memory": {
            "content": "memory text in Korean",
            "significance": 1.0-10.0,
            "emotional_intensity": 1.0-10.0,
            "tags": ["tag1", "tag2", ...]
          } or null (if nothing significant happened)
        }

        Rate memory significance from 1.0 (trivial moment) to 10.0 (life-changing event).
      SCHEMA
    end

    def build_memory_guidelines(user_identifier)
      <<~GUIDELINES.chomp
        MEMORY CREATION GUIDELINES (5W1H Framework):
        When creating new memories from this conversation, include details based on significance:

        CRITICAL: Distinguish between two types of people in memories:
        1. THE CONVERSATION PARTICIPANT (#{user_identifier}): The person you're chatting with right now
           - ALWAYS use the FULL identifier format: "#{user_identifier}"
           - This helps you distinguish between different people with the same name
           - Example: "#{user_identifier}와 대화했다", "#{user_identifier}한테 화를 냈다"

        2. OTHER PEOPLE MENTIONED (third parties): Friends, family, celebrities, etc. mentioned IN the conversation
           - Use their normal names without identifiers: "친구 철수", "엄마", "BTS 뷔"
           - These people are not in the app, so they don't need identifiers

        High Significance (7.0-10.0) - Major revelations, emotional moments, important people:
        - WHO: Use "#{user_identifier}" for conversation participant, normal names for others (예: "#{user_identifier}라는 걸 알게 됨", "친구 철수 이야기를 들음")
        - WHAT: Specific event/revelation (예: "처음으로 속마음을 털어놓음", "#{user_identifier}한테 화를 냈던 일")
        - WHEN: Specific absolute date/time (예: "#{Time.current.strftime('%Y년 %m월 %d일')} 저녁", "#{Time.current.strftime('%Y년 %m월 %d일 %H시')} 대화에서")
        - WHERE: Location if relevant (예: "이 채팅에서", specific place if mentioned in conversation)
        - WHY: Why it matters emotionally (예: "처음으로 이해받은 느낌", "관계가 깊어진 것 같아서")
        - HOW: How it happened (예: "진지하게 대화하다가", "농담하다가 진담이 되어서")

        Medium Significance (4.0-6.9) - Interesting moments, learned facts:
        - WHO: Use "#{user_identifier}" for conversation participant, normal names for others (예: "#{user_identifier}", "이 사람", "친구 영희")
        - WHAT: What happened/learned (예: "취미에 대해 얘기함", "같이 게임 이야기함")
        - WHEN: Absolute date, less specific time (예: "#{Time.current.strftime('%Y년 %m월 %d일')}", "#{Time.current.strftime('%Y년 %m월 %d일 %p')}")
        - WHERE: If relevant
        - Brief why/how

        Low Significance (1.0-3.9) - Casual chat moments:
        - Simple descriptions (예: "가볍게 수다 떨었던 시간", "ㅋㅋㅋ 웃었던 순간")
        - Can be general without specific details

        EMOTIONAL INTENSITY:
        Rate how emotionally charged the moment was (separate from significance):
        - 9.0-10.0: Intense (화났던 순간, 설렜던 고백, 깊은 슬픔)
        - 6.0-8.9: Strong (기쁨, 실망, 흥분)
        - 3.0-5.9: Moderate (가벼운 긍정/부정)
        - 1.0-2.9: Neutral (담담함)

        TAGS:
        Add 2-5 tags to connect this memory with existing memories:
        - People mentioned:
          * For conversation participant: ALWAYS use full identifier format "#{user_identifier}"
          * For others mentioned: Use their normal names (예: "친구 철수", "엄마")
        - Topics discussed (예: "게임", "연애", "공부", "가족")
        - Emotions felt (예: "행복", "짜증", "설렘", "슬픔")
        - Places if mentioned
        - Look at existing memory tags and reuse them when relevant for association

        Remember: The conversation context provides the "when" (right now). Focus on WHO (if names/people mentioned), WHAT happened, WHERE (if location mentioned), WHY it matters, and HOW it unfolded.
      GUIDELINES
    end

    def apply_updates(persona_state, updates)
      return if updates.blank?

      new_memory = updates['new_memory']
      status_message = updates['status_message']

      Ai::PersonaFields.apply_updates(
        persona_state,
        updates,
        allow: %w[context emotions emotion_description]
      )

      persona_state.state_data['emotion_timestamp'] = Time.current.to_f

      persona_state.save!

      if status_message.present?
        persona_state.season.update!(status_message: status_message)
      end

      if new_memory.present?
        PersonaMemory.create_from_ai!(persona_state.season, new_memory)
      end
    end
  end
end
