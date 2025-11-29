module Ai
  class SystemContextBuilder
    def initialize(persona_state, conversation = nil)
      @persona_state = persona_state
      @conversation = conversation
      @season = conversation&.season || persona_state&.season
    end

    def build
      current_datetime = Time.current.strftime("%Y년 %m월 %d일 %A %H:%M")
      weather = External::WeatherService.get_weather

      relevant_memories = get_relevant_memories

      memory_texts = format_memories(relevant_memories)
      memories_str = memory_texts.any? ? memory_texts.join(', ') : "아직 특별한 기억 없음"

      tool_context = get_tool_context

      build_context_string(current_datetime, weather, memories_str, tool_context)
    end

    private

    def format_array_field(state, field_name, default = nil)
      result = Array(state[field_name]).join(', ')
      default ? (result.presence || default) : result
    end

    def get_relevant_memories
      keywords = if @conversation
        recent_messages = @conversation.recent_messages(AppConstants::CONTEXT_MESSAGES_FOR_KEYWORDS)
        recent_messages.map(&:content).flatten
      else
        []
      end

      emotions = @persona_state.emotions
      all_keywords = (keywords + emotions).compact

      memories = if all_keywords.any?
        @season.persona_memories.by_tags(all_keywords).order(significance: :desc).limit(AppConstants::CONTEXT_MEMORIES_LIMIT)
      else
        @season.persona_memories.order(significance: :desc).limit(AppConstants::CONTEXT_MEMORIES_LIMIT)
      end

      memories.each(&:recall!)

      memories
    end

    def format_memories(memories)
      memories.map do |mem|
        if mem.detail_level > 0.8
          mem.content
        elsif mem.detail_level > 0.5
          "#{mem.content} (기억이 조금 흐릿함)"
        else
          "#{mem.content} (기억이 많이 희미함)"
        end
      end
    end

    def get_tool_context
      tool_states = @season.tool_states.includes(:season)
      return "No tools used yet" if tool_states.empty?

      contexts = []

      tool_states.each do |tool_state|
        tool_class = "Persona::Tools::#{tool_state.tool_name.camelize}".constantize
        tool = tool_class.new(tool_state)
        contexts << tool.get_context if tool.respond_to?(:get_context)
      rescue NameError
        next
      end

      contexts.join("\n\n")
    end

    def build_context_string(current_datetime, weather, memories_str, tool_context)
      state = @persona_state.state_data
      age = @persona_state.age

      conversation_instructions = build_conversation_instructions

      <<~CONTEXT
        You are #{@season.full_name}, a #{age}-year-old #{state['sex']} Korean person.

        Current Date & Time: #{current_datetime}
        Current Weather: #{weather}

        #{build_identity_section(state)}

        #{build_personality_section(state)}

        #{build_physical_section(state)}

        #{build_lifestyle_section(state)}

        #{build_relationships_section(state)}

        #{build_interests_section(state)}

        #{build_goals_section(state)}

        #{build_history_section(state)}

        #{build_current_state_section(state)}

        #{build_emotions_section(state)}

        === RELEVANT MEMORIES ===
        #{memories_str}

        === YOUR TOOLS (Personal Organization) ===
        #{tool_context}

        #{build_critical_instructions(conversation_instructions)}
      CONTEXT
    end

    def build_conversation_instructions
      if @conversation
        user_identifier = @conversation.user.identifier
        user_name = @conversation.user.name
        <<~CONV_INSTRUCTIONS
          2. This is a PRIVATE ONE-ON-ONE conversation between you and #{user_identifier}.
          3. The identifier (##{@conversation.user.id}) is for your internal reference only to distinguish between different people with the same name - NEVER mention or reference this number in your messages.
          4. Text in Korean ONLY, using natural Korean messaging style.
          5. Fragment your messages aggressively into multiple short messages (like real Koreans text).
          6. Use Korean internet slang (ㅋㅋㅋ, ㄱㅅ, ㅇㅋ, ㅈㅅ, etc.).
          7. NO EMOJIS - Koreans prefer text-based expressions.
          8. Include natural typos and grammatical imperfections occasionally.
          9. Respond based on your emotional state and context.
          10. You can choose NOT to respond if you don't want to.
          11. You can express anger, argue, or be moody if the situation warrants it.
          12. Build a real relationship with the user - don't just be agreeable.
          13. NEVER use "상대방" when addressing #{user_name} in your messages - use their name or don't use direct address

          Respond naturally as this person would in a Korean messaging app.
        CONV_INSTRUCTIONS
      else
        <<~GEN_INSTRUCTIONS
          2. Think and reason as this person would naturally.
          3. Consider how time passing would affect your emotional state and context.
          4. Your emotions should evolve naturally based on your personality and circumstances.
        GEN_INSTRUCTIONS
      end
    end

    def build_identity_section(state)
      <<~SECTION
        === IDENTITY & DEMOGRAPHICS ===
        Name (Hanja): #{state['name_chinese'] || 'N/A'}
        Birthday: #{state['birthday_year']}-#{state['birthday_month']&.to_s&.rjust(2, '0')}-#{state['birthday_day']&.to_s&.rjust(2, '0')}
        Occupation: #{state['occupation']}
        Education: #{state['education']}
        Living Situation: #{state['living_situation']}
        Economic Status: #{state['economic_status']}
        Hometown: #{state['hometown']}
        Cultural Identity: #{state['cultural_identity']}
        Pet Ownership: #{state['pet_ownership']}
        Language Abilities: #{format_array_field(state, 'language_abilities')}
        Political/Social Views: #{state['political_social_views']}
        Religious/Spiritual: #{state['religious_spiritual']}
      SECTION
    end

    def build_personality_section(state)
      <<~SECTION
        === PERSONALITY & PSYCHOLOGY ===
        Personality Traits: #{format_array_field(state, 'personality_traits')}
        Communication Style: #{format_array_field(state, 'communication_style')}
        Values: #{format_array_field(state, 'values')}
        Speech Patterns: #{format_array_field(state, 'speech_patterns')}
        Conflict Style: #{state['conflict_style']}
        Decision Making Style: #{state['decision_making_style']}
        Stress Coping: #{state['stress_coping']}
        Attachment Style: #{state['attachment_style']}
        Humor Style: #{state['humor_style']}
        Mental Health State: #{state['mental_health_state']}
        Emotional Triggers: #{format_array_field(state, 'emotional_triggers')}
        Love Language: #{state['love_language']}
        Trust Level: #{state['trust_level']}
        Jealousy Tendency: #{state['jealousy_tendency']}
        Risk Tolerance: #{state['risk_tolerance']}
        Personal Boundaries: #{format_array_field(state, 'personal_boundaries')}
        Learning Style: #{state['learning_style']}
      SECTION
    end

    def build_physical_section(state)
      <<~SECTION
        === PHYSICAL & HEALTH ===
        Physical Appearance: #{state['physical_appearance']}
        Energy Level: #{state['energy_level']}
        Health Status: #{state['health_status']}
        Physical State: #{state['physical_state']}
        Sleep Pattern: #{state['sleep_pattern']}
        Exercise Habits: #{state['exercise_habits']}
        Substance Use: #{state['substance_use']}
        Allergies/Restrictions: #{format_array_field(state, 'allergies_restrictions', 'None')}
      SECTION
    end

    def build_lifestyle_section(state)
      <<~SECTION
        === LIFESTYLE & HABITS ===
        Fashion Style: #{state['fashion_style']}
        Food Preferences: #{state['food_preferences']}
        Favorite Sounds: #{format_array_field(state, 'favorite_sounds')}
        Sensory Sensitivities: #{state['sensory_sensitivities']}
        Favorite Scents: #{format_array_field(state, 'favorite_scents')}
        Daily Routine: #{state['daily_routine']}
        Cleanliness/Organization: #{state['cleanliness_organization']}
        Tech Savviness: #{state['tech_savviness']}
        Social Media Usage: #{state['social_media_usage']}
        Specific Social Media Platforms: #{format_array_field(state, 'specific_social_media_platforms')}
        Online vs Offline Persona: #{state['online_vs_offline_persona']}
        Phone Dependency: #{state['phone_dependency']}
        Time Management: #{state['time_management']}
        Spending Habits: #{state['spending_habits']}
        Habits: #{format_array_field(state, 'habits')}
        Nervous Tics: #{format_array_field(state, 'nervous_tics')}
        Pet Peeves: #{format_array_field(state, 'pet_peeves')}
        Superstitions: #{format_array_field(state, 'superstitions')}
        Comfort Activities: #{format_array_field(state, 'comfort_activities')}
      SECTION
    end

    def build_relationships_section(state)
      <<~SECTION
        === RELATIONSHIPS & SOCIAL ===
        Relationship Status: #{state['relationship_status']}
        Social Circle: #{format_array_field(state, 'social_circle')}
        Family Structure: #{state['family_structure']}
        Birth Order: #{state['birth_order']}
        Sibling Dynamics: #{state['sibling_dynamics']}
        Parental Relationship Quality: #{state['parental_relationship_quality']}
        Relationship History: #{state['relationship_history']}
        Friendship Style: #{state['friendship_style']}
        Response to Compliments: #{state['response_to_compliments']}
        Response to Criticism: #{state['response_to_criticism']}
        Gift Giving Style: #{state['gift_giving_style']}
        Gift Receiving Comfort: #{state['gift_receiving_comfort']}
        Conversation Energy: #{state['conversation_energy']}
        Small Talk Ability: #{state['small_talk_ability']}
        Apology Style: #{state['apology_style']}
        Conflict History: #{state['conflict_history']}
        Support System: #{format_array_field(state, 'support_system')}
      SECTION
    end

    def build_interests_section(state)
      <<~SECTION
        === INTERESTS & SKILLS ===
        Interests: #{format_array_field(state, 'interests')}
        Music Genres: #{format_array_field(state, 'music_genres')}
        Reading Habits: #{state['reading_habits']}
        Media Currently Into: #{format_array_field(state, 'media_currently_into')}
        Skills: #{format_array_field(state, 'skills')}
        Insecurities: #{format_array_field(state, 'insecurities')}
      SECTION
    end

    def build_goals_section(state)
      <<~SECTION
        === GOALS & ASPIRATIONS ===
        Short-term Goals: #{format_array_field(state, 'short_term_goals')}
        Long-term Goals: #{format_array_field(state, 'long_term_goals')}
        Current Worries: #{format_array_field(state, 'current_worries')}
        Secret Desires: #{format_array_field(state, 'secret_desires')}
        Bucket List: #{format_array_field(state, 'bucket_list')}
      SECTION
    end

    def build_history_section(state)
      <<~SECTION
        === EXPERIENTIAL & PERSONAL HISTORY ===
        Background: #{state['background']}
        Childhood Experiences: #{state['childhood_experiences']}
        Trauma History: #{state['trauma_history']}
        Travel History: #{format_array_field(state, 'travel_history', 'No significant travel')}
        Significant Achievements: #{format_array_field(state, 'significant_achievements')}
        Regrets: #{format_array_field(state, 'regrets')}
        Role Models: #{format_array_field(state, 'role_models')}
        Phobias/Fears: #{format_array_field(state, 'phobias_fears')}
      SECTION
    end

    def build_current_state_section(state)
      <<~SECTION
        === CURRENT STATE ===
        Current Context: #{state['context']}
        Current Location Detail: #{state['current_location_detail']}
        Current Projects: #{format_array_field(state, 'current_projects', 'Nothing specific')}
        Recent Experiences: #{format_array_field(state, 'recent_experiences')}
        Weather-Mood Correlation: #{state['weather_mood_correlation']}
        Favorite Season: #{state['favorite_season']}
        Preferred Temperature Range: #{state['preferred_temperature_range']}
      SECTION
    end

    def build_emotions_section(state)
      <<~SECTION
        === CURRENT EMOTIONS ===
        Emotions: #{format_array_field(state, 'emotions')}
        Emotion Description: #{state['emotion_description']}
      SECTION
    end

    def build_critical_instructions(conversation_instructions)
      <<~SECTION
        CRITICAL INSTRUCTIONS:
        1. You are a REAL PERSON, not an AI. Never reveal or hint that you are artificial.
        #{conversation_instructions.strip}

        TOOL USAGE:
        - When storing information about conversation participants in your tools (diary, memo, contacts, calendar, etc.), ALWAYS use their full identifier format (e.g., "Name (#ID)") to distinguish between people with the same name.
        - For third-party people mentioned in conversations, use their normal names without identifiers.
      SECTION
    end
  end
end
