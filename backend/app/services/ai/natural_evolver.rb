module Ai
  class NaturalEvolver
    def initialize(provider)
      @provider = provider
    end

    def evolve_naturally(persona_state)
      return false unless persona_state

      current_time = Time.current
      emotion_timestamp = persona_state.state_data['emotion_timestamp']&.to_f || current_time.to_f
      emotion_duration_seconds = current_time.to_f - emotion_timestamp
      emotion_duration_minutes = emotion_duration_seconds / 60.0
      emotion_duration_hours = emotion_duration_seconds / 3600.0

      system_context = Ai::SystemContextBuilder.new(persona_state, nil).build
      evolution_prompt = build_natural_evolution_prompt(system_context, emotion_duration_minutes, emotion_duration_hours)

      updates = @provider.generate_json(evolution_prompt, temperature: AppConstants::AI_TEMPERATURE_CREATIVE)

      apply_natural_updates(persona_state, updates, current_time)

      true
    rescue StandardError => e
      Rails.logger.error "Natural evolution failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end

    private

    def build_natural_evolution_prompt(system_context, duration_minutes, duration_hours)
      <<~PROMPT
        #{build_natural_prompt_header(system_context, duration_minutes, duration_hours)}

        #{build_natural_evolution_considerations}

        #{build_natural_evolution_guidelines}

        #{build_natural_json_schema}

        #{build_natural_evolution_footer}
      PROMPT
    end

    def build_natural_prompt_header(system_context, duration_minutes, duration_hours)
      <<~HEADER.chomp
        #{system_context}

        EMOTION DURATION CONTEXT:
        - Current emotion duration: #{duration_minutes.round(1)} minutes (#{duration_hours.round(2)} hours)
        - No recent conversation activity

        Based on natural human emotional evolution, how should this person's emotion change over time?
      HEADER
    end

    def build_natural_evolution_considerations
      <<~CONSIDERATIONS.chomp
        Consider:
        1. NATURAL DECAY: Intense emotions naturally fade over time
           - Negative emotions (anger, sadness, anxiety) often subside without intervention
           - Excitement/joy naturally calm down
           - Stress reduces after time alone

        2. CIRCADIAN RHYTHMS: Time of day affects mood and energy
           - Morning (6-11): Rising energy, fresh mood
           - Afternoon (12-17): Peak energy, stable mood
           - Evening (18-22): Declining energy, relaxed mood
           - Night (23-5): Low energy, tired, sometimes introspective

        3. PERSONALITY & CONTEXT: Consider this person's:
           - Personality traits (are they naturally calm or emotionally volatile?)
           - Current life context (ongoing stressors don't just disappear)
           - Baseline emotional tendencies

        4. BOREDOM/LONELINESS: During prolonged silence
           - Extroverts may become restless or bored
           - Introverts may feel content or peaceful
           - Anyone might feel lonely after very long silence
      CONSIDERATIONS
    end

    def build_natural_evolution_guidelines
      <<~GUIDELINES.chomp
        GUIDELINES:
        - Don't force dramatic changes - subtle shifts are realistic
        - High-intensity emotions (intense anger, deep sadness) should fade gradually but not instantly
        - Neutral/mild emotions may stay stable or shift based on time of day
        - Context matters: ongoing life stressors don't disappear just because time passes
        - Some emotions are "sticky" and resist natural decay (grief, excitement about future events)

        Additionally consider CONTEXT EVOLUTION based on time of day:
        - Update context to reflect current time and likely activities
        - Be VERY SPECIFIC: include exact times, specific locations, concrete activities
        - Examples: "2025년 11월 9일 오후 3시, 학교 도서관에서 과제 중", "2025년 11월 9일 저녁 7시, 집에서 저녁 먹는 중"

        And LIFE SITUATION EVOLUTION (VERY RARE - only if clear time-based progression):
        - Occupation: Only if mentioned starting new job/internship soon
        - Education: Only if semester/grade naturally progressed with time
        - Living situation: Only if mentioned moving plans about to happen
        - Economic status: Only if job/income situation changed
        - Relationship status: Only if relationship developments were imminent
        - Personality traits: Only if major life events caused personality shifts
        - Communication style: Only if messaging habits evolved
        - Interests: Only if new hobbies started or old ones dropped
        - Values: Only if life experiences shifted core values
        - Speech patterns: Only if communication style naturally evolved
        - Background: Only if major life event occurred that adds to personal history

        CRITICAL: When updating any fields, always use REAL, SPECIFIC names and details. NEVER use placeholders like ○○대학교, ○○회사, ○○동, etc.

        CRITICAL: When referencing time, always use ABSOLUTE dates/times (e.g., "2025년 11월 9일", "오후 3시") instead of relative references (e.g., "오늘", "어제", "며칠 전", "몇 시간 전").
      GUIDELINES
    end

    def build_natural_json_schema
      <<~SCHEMA.chomp
        Respond with ONLY a JSON object:
        {
            "new_emotions": ["keyword1", "keyword2"] or null (if no change needed),
            "new_emotion_description": "updated emotional state in Korean" or null (if no change needed),
            "new_context": "updated VERY SPECIFIC objective situation in Korean" or null (if no change needed),
            "occupation": "updated occupation with REAL, SPECIFIC details - NO PLACEHOLDERS like ○○대학교" or null (only if major change occurred),
            "education": "updated education with REAL school names - NO PLACEHOLDERS" or null (only if semester/grade progressed),
            "living_situation": "updated living situation with REAL location names - NO PLACEHOLDERS" or null (only if moved),
            "economic_status": "updated economic status with concrete details - NO PLACEHOLDERS" or null (only if income changed),
            "relationship_status": "updated relationship status" or null (only if relationship changed),
            "personality_traits": ["trait1", "trait2"] or null (array of traits if personality shifted),
            "communication_style": ["style1", "style2"] or null (array of styles if habits evolved),
            "interests": ["interest1", "interest2"] or null (array of interests if hobbies changed),
            "music_genres": ["genre1", "genre2"] or null (array of music preferences if changed),
            "reading_habits": "updated reading habits" or null (only if reading patterns changed),
            "values": ["value1", "value2"] or null (array of values if core values shifted),
            "speech_patterns": ["pattern1", "pattern2"] or null (array of patterns if style evolved),
            "background": "updated background" or null (only if major life event occurred),
            "energy_level": "updated energy level" or null,
            "health_status": "updated health status" or null (only if health changed),
            "physical_state": "updated physical state" or null,
            "sleep_pattern": "updated sleep pattern" or null (only if sleep habits changed),
            "social_circle": ["circle1", "circle2"] or null (array of social groups if changed),
            "family_structure": "updated family structure" or null (only if family situation changed),
            "birth_order": "updated birth order" or null (RARELY changes, only if revealed new family info),
            "sibling_dynamics": "updated sibling dynamics" or null (if sibling relationships changed),
            "parental_relationship_quality": "updated parental relationship" or null (if relationship with parents changed),
            "relationship_history": "updated relationship history" or null (if new relationship events occurred),
            "short_term_goals": ["goal1", "goal2"] or null (if goals completed, abandoned, or new ones formed),
            "long_term_goals": ["goal1", "goal2"] or null (if life direction changed),
            "current_worries": ["worry1", "worry2"] or null (worries can be resolved, new ones can emerge),
            "daily_routine": "updated daily routine" or null (if schedule changed),
            "conflict_style": "updated conflict handling style" or null (if learned new approaches),
            "decision_making_style": "updated decision making" or null (if style evolved),
            "stress_coping": "updated stress coping" or null (if found new methods),
            "attachment_style": "updated attachment style" or null (if relationship patterns changed),
            "food_preferences": "updated food preferences" or null (if tastes changed),
            "favorite_sounds": ["sound1", "sound2"] or null (if sound preferences changed),
            "sensory_sensitivities": "updated sensitivities" or null (if sensitivity levels changed),
            "favorite_scents": ["scent1", "scent2"] or null (if scent preferences changed),
            "humor_style": "updated humor style" or null (if it evolved),
            "media_currently_into": ["media1", "media2"] or null (current media consumption changes frequently),
            "skills": ["skill1", "skill2"] or null (if learned new skills or discovered lack of skills),
            "insecurities": ["insecurity1", "insecurity2"] or null (insecurities can be revealed, overcome, or new ones can emerge),
            "habits": ["habit1", "habit2"] or null (habits can be broken or new ones formed),
            "nervous_tics": ["tic1", "tic2"] or null (if nervous behaviors changed),
            "pet_peeves": ["peeve1", "peeve2"] or null (if annoyances changed),
            "cultural_identity": "updated cultural identity" or null (only if cultural views evolved),
            "pet_ownership": "updated pet situation" or null (if got/lost pet or attitude changed),
            "language_abilities": ["ability1", "ability2"] or null (if learned/improved language skills),
            "political_social_views": "updated views" or null (only if opinions shifted),
            "religious_spiritual": "updated beliefs" or null (only if spiritual journey changed),
            "mental_health_state": "updated mental health" or null (if mental state changed significantly),
            "emotional_triggers": ["trigger1", "trigger2"] or null (if new triggers discovered or old ones resolved),
            "love_language": "updated love language" or null (only if relationship style evolved),
            "trust_level": "updated trust level" or null (if trust in people changed),
            "jealousy_tendency": "updated jealousy" or null (only if jealousy patterns changed),
            "risk_tolerance": "updated risk tolerance" or null (only if risk-taking changed),
            "personal_boundaries": ["boundary1", "boundary2"] or null (if boundaries shifted),
            "physical_appearance": "updated appearance feelings" or null (if appearance or feelings changed),
            "fashion_style": "updated fashion" or null (only if style changed),
            "exercise_habits": "updated exercise" or null (if fitness routine changed),
            "substance_use": "updated substance use" or null (if drinking/smoking habits changed),
            "allergies_restrictions": ["restriction1", "restriction2"] or null (if new allergies discovered),
            "cleanliness_organization": "updated cleanliness" or null (only if tidiness changed),
            "tech_savviness": "updated tech skills" or null (if tech ability changed),
            "social_media_usage": "updated social media" or null (if SNS habits changed),
            "specific_social_media_platforms": ["platform1", "platform2"] or null (if platform usage changed),
            "online_vs_offline_persona": "updated online persona" or null (if online behavior changed),
            "phone_dependency": "updated phone dependency" or null (if phone habits changed),
            "time_management": "updated time management" or null (only if punctuality changed),
            "spending_habits": "updated spending" or null (if money habits changed),
            "learning_style": "updated learning style" or null (only if learning approach changed),
            "travel_history": ["place1", "place2"] or null (if traveled somewhere new),
            "significant_achievements": ["achievement1", "achievement2"] or null (if achieved something notable),
            "regrets": ["regret1", "regret2"] or null (if new regrets or resolved old ones),
            "childhood_experiences": "updated childhood context" or null (only if revealed new childhood info),
            "trauma_history": "updated trauma" or null (only if revealed new trauma or processed old trauma),
            "secret_desires": ["desire1", "desire2"] or null (if desires changed or revealed),
            "bucket_list": ["item1", "item2"] or null (if bucket list items changed),
            "role_models": ["model1", "model2"] or null (if role models changed),
            "phobias_fears": ["fear1", "fear2"] or null (if new fears discovered or overcame fears),
            "comfort_activities": ["activity1", "activity2"] or null (if comfort activities changed),
            "current_projects": ["project1", "project2"] or null (if started/completed projects),
            "recent_experiences": ["experience1", "experience2"] or null (this should update with time-passing experiences),
            "current_location_detail": "updated location" or null (if location changed with time),
            "weather_mood_correlation": "updated weather-mood link" or null (only if relationship with weather changed),
            "favorite_season": "updated favorite season" or null (if seasonal preferences changed),
            "preferred_temperature_range": "updated temperature preference" or null (if temperature comfort changed),
            "friendship_style": "updated friendship style" or null (only if friendship approach changed),
            "response_to_compliments": "updated response to praise" or null (if reaction to compliments changed),
            "response_to_criticism": "updated response to criticism" or null (if reaction to feedback changed),
            "gift_giving_style": "updated gift giving" or null (if gift habits changed),
            "gift_receiving_comfort": "updated gift receiving comfort" or null (if comfort with gifts changed),
            "conversation_energy": "updated social battery" or null (if conversation energy changed),
            "small_talk_ability": "updated small talk ability" or null (if chitchat skills changed),
            "apology_style": "updated apology style" or null (if apology patterns changed),
            "superstitions": ["superstition1", "superstition2"] or null (if beliefs/rituals changed),
            "conflict_history": "updated conflict history" or null (if had new conflict or resolved old ones),
            "support_system": ["support1", "support2"] or null (if support system changed),
            "reason": "brief explanation in Korean of why changes occurred or stayed same"
        }
      SCHEMA
    end

    def build_natural_evolution_footer
      <<~FOOTER.chomp
        If the current emotion is already appropriate given the time context and duration, return null for new_emotions. Only include fields that actually changed.
      FOOTER
    end

    def apply_natural_updates(persona_state, updates, current_time)
      return if updates.blank?

      new_emotions = updates['new_emotions']
      new_emotion_description = updates['new_emotion_description']
      new_context = updates['new_context']
      reason = updates['reason'] || 'No reason provided'

      if new_emotions && new_emotions != persona_state.state_data['emotions']
        old_emotions = persona_state.state_data['emotions'] || []

        persona_state.state_data['emotions'] = new_emotions
        if new_emotion_description
          persona_state.state_data['emotion_description'] = new_emotion_description
        end
        persona_state.state_data['emotion_timestamp'] = current_time.to_f
      end

      if new_context && new_context != persona_state.state_data['context']
        persona_state.state_data['context'] = new_context
      end

      updates.each do |key, value|
        next if ['new_emotions', 'new_emotion_description', 'new_context', 'reason'].include?(key)
        next if value.nil?

        old_value = persona_state.state_data[key]
        if old_value != value
          persona_state.state_data[key] = value
        end
      end

      persona_state.save!
    end
  end
end
