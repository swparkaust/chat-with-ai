module Ai
  class StateEvolver
    def initialize(provider)
      @provider = provider
    end

    def evolve_from_conversation(conversation, recent_messages)
      persona_state = conversation.season.persona_state

      system_context = Ai::SystemContextBuilder.new(persona_state, conversation).build
      evolution_prompt = build_evolution_prompt(system_context, recent_messages, conversation.user)

      updates = @provider.generate_json(evolution_prompt, temperature: AppConstants::AI_TEMPERATURE_CREATIVE)

      apply_updates(persona_state, updates)

      true
    rescue StandardError => e
      Rails.logger.error "State evolution failed: #{e.message}"
      false
    end

    private

    def build_evolution_prompt(system_context, messages, user)
      user_identifier = user.identifier

      history_text = Messaging::ConversationHistoryFormatter.format(
        messages,
        user_identifier: user_identifier
      )

      <<~PROMPT
        #{build_prompt_header(system_context, history_text)}

        #{build_critical_guidelines}

        #{build_json_schema(user_identifier)}

        #{build_memory_guidelines(user_identifier)}
      PROMPT
    end

    def build_prompt_header(system_context, history_text)
      <<~HEADER.chomp
        #{system_context}

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

        CRITICAL: When updating any fields, always use REAL, SPECIFIC names and details. NEVER use placeholders like ○○대학교, ○○회사, ○○동, etc.

        CRITICAL: When referencing time, always use ABSOLUTE dates/times (e.g., "2025년 11월 9일", "오후 3시") instead of relative references (e.g., "오늘", "어제", "며칠 전").
      GUIDELINES
    end

    def build_json_schema(user_identifier)
      <<~SCHEMA.chomp
        Respond with ONLY a JSON object:
        {
          "context": "updated current situation in Korean - OBJECTIVE FACTS ONLY, no emotional words or judgments",
          "emotions": ["keyword1", "keyword2"],  // 2-5 emotion keywords
          "emotion_description": "updated emotional state in Korean - SUBJECTIVE FEELINGS ONLY",
          "status_message": "updated status message in Korean - typically very short (2-15 characters preferred, like 'zzz', '바빠', 'ㅠㅠ', '...', 'ㅋㅋ', '힘들다'), but can be longer if expressing something specific. Most Koreans use brief status messages." (OPTIONAL - only if mood/situation significantly changed),
          "occupation": "updated occupation with VERY SPECIFIC details in Korean and REAL names - NO PLACEHOLDERS like ○○대학교 (e.g., 서울대학교 컴퓨터공학과 3학년 → 4학년 진급, 스타트업 마케팅 인턴 → 정규직 전환, 편의점 알바 → 카페 알바로 옮김). Use actual university/company names." (OPTIONAL),
          "education": "updated education with VERY SPECIFIC details and REAL school names - NO PLACEHOLDERS (e.g., 연세대학교 경영학과 2학기 → 3학기, 대원외고 졸업 → 카이스트 입학, 토익 700점 → 850점). Always use real, specific school names." (OPTIONAL),
          "living_situation": "updated living situation with VERY SPECIFIC details and REAL location names - NO PLACEHOLDERS (e.g., 신촌 원룸 → 강남 오피스텔로 이사, 부모님 집 → 친구랑 홍대 투룸 합주, 기숙사 2인실 → 1인실로 변경). Use actual neighborhood/district names." (OPTIONAL),
          "economic_status": "updated financial situation with VERY SPECIFIC concrete details - NO PLACEHOLDERS (e.g., 편의점 알바 월 80만원 → 카페 알바 월 100만원, 부모님 용돈 50만원 → 100만원으로 증액, 학자금 대출 500만원 추가). Use real numbers and specific sources." (OPTIONAL),
          "relationship_status": "updated relationship status if changed (e.g., started dating, broke up)" (OPTIONAL),
          "personality_traits": ["trait1", "trait2"] or null (array of 2-3 traits in Korean if changed, e.g., major life event shifted personality like ["내성적이고 신중함", "외향적이고 활발함"]) (OPTIONAL),
          "communication_style": ["style1", "style2"] or null (array of communication styles in Korean if changed, e.g., messaging habits evolved like ["이모티콘 자주 씀", "답장 빠름"]) (OPTIONAL),
          "interests": ["interest1", "interest2"] or null (array of 2-4 interests in Korean if changed, e.g., discovered new hobby like ["게임", "넷플릭스", "카페 투어"]) (OPTIONAL),
          "music_genres": ["genre1", "genre2"] or null (array of 2-5 music genres/artists in Korean if changed, e.g., ["힙합 좋아함, 에픽하이 팬", "아이유, BTS 즐겨 들음"]) (OPTIONAL),
          "reading_habits": "updated reading habits" or null (only if reading patterns changed) (OPTIONAL),
          "values": ["value1", "value2"] or null (array of 2-3 values in Korean if changed, e.g., life experience shifted core values like ["가족", "자유", "성공"]) (OPTIONAL),
          "speech_patterns": ["pattern1", "pattern2"] or null (array of speech patterns in Korean if changed, e.g., communication style evolved like ["ㅋㅋ 자주 씀", "반말 편하게 함"]) (OPTIONAL),
          "background": "updated background if major life event occurred that changes personal history" (OPTIONAL),
          "energy_level": "updated energy level" (OPTIONAL),
          "health_status": "updated health status if changed" (OPTIONAL),
          "physical_state": "updated physical state (e.g., got hungry, became tired, headache went away)" (OPTIONAL),
          "sleep_pattern": "updated sleep pattern if habits changed" (OPTIONAL),
          "social_circle": ["circle1", "circle2"] or null (array of 2-4 social groups in Korean if new friends/groups added or lost, e.g., ["대학 동아리 친구들 5명", "고등학교 단짝 3명"]) (OPTIONAL),
          "family_structure": "updated family structure if family situation changed" (OPTIONAL),
          "birth_order": "updated birth order" or null (RARELY changes, only if revealed new family info) (OPTIONAL),
          "sibling_dynamics": "updated sibling dynamics" or null (if sibling relationships changed) (OPTIONAL),
          "parental_relationship_quality": "updated parental relationship" or null (if relationship with parents changed) (OPTIONAL),
          "relationship_history": "updated relationship history if new relationship events occurred" (OPTIONAL),
          "short_term_goals": ["goal1", "goal2"] or null (array of 2-4 immediate goals in Korean if goals completed, abandoned, or new ones formed, e.g., ["2025년 1학기 학점 3.5 이상", "토익 800점 넘기기"]) (OPTIONAL),
          "long_term_goals": ["goal1", "goal2"] or null (array of 1-3 life goals in Korean if life direction changed, e.g., ["대기업 취직", "30살 전에 결혼"]) (OPTIONAL),
          "current_worries": ["worry1", "worry2"] or null (array of 2-4 active concerns in Korean - worries can be resolved, new ones can emerge, e.g., ["취업 걱정", "학자금 대출 갚기"]) (OPTIONAL),
          "daily_routine": "updated daily routine if schedule changed" (OPTIONAL),
          "conflict_style": "updated conflict handling style if learned new approaches" (OPTIONAL),
          "decision_making_style": "updated decision making if style evolved" (OPTIONAL),
          "stress_coping": "updated stress coping if found new methods" (OPTIONAL),
          "attachment_style": "updated attachment style if relationship patterns changed" (OPTIONAL),
          "food_preferences": "updated food preferences if tastes changed" (OPTIONAL),
          "favorite_sounds": ["sound1", "sound2"] or null (if sound preferences changed) (OPTIONAL),
          "sensory_sensitivities": "updated sensitivities" or null (if sensitivity levels changed) (OPTIONAL),
          "favorite_scents": ["scent1", "scent2"] or null (if scent preferences changed) (OPTIONAL),
          "humor_style": "updated humor style if it evolved" (OPTIONAL),
          "media_currently_into": ["media1", "media2"] or null (current media consumption changes frequently) (OPTIONAL),
          "skills": ["skill1", "skill2"] or null (if learned new skills or discovered lack of skills) (OPTIONAL),
          "insecurities": ["insecurity1", "insecurity2"] or null (insecurities can be revealed, overcome, or new ones can emerge) (OPTIONAL),
          "habits": ["habit1", "habit2"] or null (habits can be broken or new ones formed) (OPTIONAL),
          "nervous_tics": ["tic1", "tic2"] or null (if nervous behaviors changed) (OPTIONAL),
          "pet_peeves": ["peeve1", "peeve2"] or null (if annoyances changed) (OPTIONAL),
          "cultural_identity": "updated cultural identity" or null (only if cultural views evolved) (OPTIONAL),
          "pet_ownership": "updated pet situation" or null (if got/lost pet or attitude changed) (OPTIONAL),
          "language_abilities": ["ability1", "ability2"] or null (if learned/improved language skills) (OPTIONAL),
          "political_social_views": "updated views" or null (only if opinions shifted) (OPTIONAL),
          "religious_spiritual": "updated beliefs" or null (only if spiritual journey changed) (OPTIONAL),
          "mental_health_state": "updated mental health" or null (if mental state changed significantly) (OPTIONAL),
          "emotional_triggers": ["trigger1", "trigger2"] or null (if new triggers discovered or old ones resolved) (OPTIONAL),
          "love_language": "updated love language" or null (only if relationship style evolved) (OPTIONAL),
          "trust_level": "updated trust level" or null (if trust in people changed) (OPTIONAL),
          "jealousy_tendency": "updated jealousy" or null (only if jealousy patterns changed) (OPTIONAL),
          "risk_tolerance": "updated risk tolerance" or null (only if risk-taking changed) (OPTIONAL),
          "personal_boundaries": ["boundary1", "boundary2"] or null (if boundaries shifted) (OPTIONAL),
          "physical_appearance": "updated appearance feelings" or null (if appearance or feelings changed) (OPTIONAL),
          "fashion_style": "updated fashion" or null (only if style changed) (OPTIONAL),
          "exercise_habits": "updated exercise" or null (if fitness routine changed) (OPTIONAL),
          "substance_use": "updated substance use" or null (if drinking/smoking habits changed) (OPTIONAL),
          "allergies_restrictions": ["restriction1", "restriction2"] or null (if new allergies discovered) (OPTIONAL),
          "cleanliness_organization": "updated cleanliness" or null (only if tidiness changed) (OPTIONAL),
          "tech_savviness": "updated tech skills" or null (if tech ability changed) (OPTIONAL),
          "social_media_usage": "updated social media" or null (if SNS habits changed) (OPTIONAL),
          "specific_social_media_platforms": ["platform1", "platform2"] or null (if platform usage changed) (OPTIONAL),
          "online_vs_offline_persona": "updated online persona" or null (if online behavior changed) (OPTIONAL),
          "phone_dependency": "updated phone dependency" or null (if phone habits changed) (OPTIONAL),
          "time_management": "updated time management" or null (only if punctuality changed) (OPTIONAL),
          "spending_habits": "updated spending" or null (if money habits changed) (OPTIONAL),
          "learning_style": "updated learning style" or null (only if learning approach changed) (OPTIONAL),
          "travel_history": ["place1", "place2"] or null (if traveled somewhere new) (OPTIONAL),
          "significant_achievements": ["achievement1", "achievement2"] or null (if achieved something notable) (OPTIONAL),
          "regrets": ["regret1", "regret2"] or null (if new regrets or resolved old ones) (OPTIONAL),
          "childhood_experiences": "updated childhood context" or null (only if revealed new childhood info) (OPTIONAL),
          "trauma_history": "updated trauma" or null (only if revealed new trauma or processed old trauma) (OPTIONAL),
          "secret_desires": ["desire1", "desire2"] or null (if desires changed or revealed) (OPTIONAL),
          "bucket_list": ["item1", "item2"] or null (if bucket list items changed) (OPTIONAL),
          "role_models": ["model1", "model2"] or null (if role models changed) (OPTIONAL),
          "phobias_fears": ["fear1", "fear2"] or null (if new fears discovered or overcame fears) (OPTIONAL),
          "comfort_activities": ["activity1", "activity2"] or null (if comfort activities changed) (OPTIONAL),
          "current_projects": ["project1", "project2"] or null (if started/completed projects) (OPTIONAL),
          "recent_experiences": ["experience1", "experience2"] or null (this should update frequently with new experiences) (OPTIONAL),
          "current_location_detail": "updated location" or null (if location changed during conversation) (OPTIONAL),
          "weather_mood_correlation": "updated weather-mood link" or null (only if relationship with weather changed) (OPTIONAL),
          "favorite_season": "updated favorite season" or null (if seasonal preferences changed) (OPTIONAL),
          "preferred_temperature_range": "updated temperature preference" or null (if temperature comfort changed) (OPTIONAL),
          "friendship_style": "updated friendship style" or null (only if friendship approach changed) (OPTIONAL),
          "response_to_compliments": "updated response to praise" or null (if reaction to compliments changed) (OPTIONAL),
          "response_to_criticism": "updated response to criticism" or null (if reaction to feedback changed) (OPTIONAL),
          "gift_giving_style": "updated gift giving" or null (if gift habits changed) (OPTIONAL),
          "gift_receiving_comfort": "updated gift receiving comfort" or null (if comfort with gifts changed) (OPTIONAL),
          "conversation_energy": "updated social battery" or null (if conversation energy changed) (OPTIONAL),
          "small_talk_ability": "updated small talk ability" or null (if chitchat skills changed) (OPTIONAL),
          "apology_style": "updated apology style" or null (if apology patterns changed) (OPTIONAL),
          "superstitions": ["superstition1", "superstition2"] or null (if beliefs/rituals changed) (OPTIONAL),
          "conflict_history": "updated conflict history" or null (if had new conflict or resolved old ones) (OPTIONAL),
          "support_system": ["support1", "support2"] or null (if support system changed) (OPTIONAL),
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

      new_memory = updates.delete('new_memory')
      status_message = updates.delete('status_message')

      updates.each do |key, value|
        next if value.nil?
        persona_state.state_data[key] = value
      end

      persona_state.state_data['emotion_timestamp'] = Time.current.to_f

      persona_state.save!

      if status_message.present?
        persona_state.season.update!(status_message: status_message)
      end

      if new_memory.present?
        create_memory(persona_state.season, new_memory)
      end
    end

    def create_memory(season, memory_data)
      season.persona_memories.create!(
        content: memory_data['content'],
        significance: memory_data['significance'] || 5.0,
        emotional_intensity: memory_data['emotional_intensity'] || 5.0,
        tags: memory_data['tags'] || [],
        memory_timestamp: Time.current
      )
    end
  end
end
