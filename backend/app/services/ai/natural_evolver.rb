module Ai
  class NaturalEvolver
    def initialize(router:)
      @router = router
    end

    def evolve_naturally(persona_state)
      return false unless persona_state

      current_time = Time.current
      emotion_timestamp = persona_state.state_data['emotion_timestamp']&.to_f || current_time.to_f
      emotion_duration_seconds = current_time.to_f - emotion_timestamp
      emotion_duration_minutes = emotion_duration_seconds / 60.0
      emotion_duration_hours = emotion_duration_seconds / 3600.0

      system_context = Ai::SystemContextBuilder.new(persona_state, nil).build
      evolution_prompt = build_natural_evolution_prompt(emotion_duration_minutes, emotion_duration_hours)

      response = @router.call(task: :natural_evolution, system: system_context, prompt: evolution_prompt)

      if response.text.blank?
        Rails.logger.error "Natural evolution failed: blank AI response"
        return false
      end

      updates = Ai::JsonParsing.parse_object(response.text)
      Ai::JsonParsing.coerce_string_array!(updates, 'new_emotions')

      apply_natural_updates(persona_state, updates, current_time)

      true
    rescue StandardError => e
      Rails.logger.error "Natural evolution failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end

    private

    def build_natural_evolution_prompt(duration_minutes, duration_hours)
      <<~PROMPT
        #{build_natural_prompt_header(duration_minutes, duration_hours)}

        #{build_natural_evolution_considerations}

        #{build_natural_evolution_guidelines}

        #{build_natural_json_schema}

        #{build_natural_evolution_footer}
      PROMPT
    end

    def build_natural_prompt_header(duration_minutes, duration_hours)
      <<~HEADER.chomp
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

        #{Ai::PersonaFields.critical_data_guidelines}
      GUIDELINES
    end

    def build_natural_json_schema
      <<~SCHEMA.chomp
        Respond with ONLY a JSON object:
        {
            "new_emotions": ["keyword1", "keyword2"] or null (if no change needed),
            "new_emotion_description": "updated emotional state in Korean" or null (if no change needed),
            "new_context": "updated VERY SPECIFIC objective situation in Korean" or null (if no change needed),
        #{Ai::PersonaFields.schema_lines(indent: '    ')}
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

      if new_emotions && new_emotions != persona_state.state_data['emotions']
        persona_state.state_data['emotions'] = new_emotions
        if new_emotion_description
          persona_state.state_data['emotion_description'] = new_emotion_description
        end
        persona_state.state_data['emotion_timestamp'] = current_time.to_f
      end

      if new_context && new_context != persona_state.state_data['context']
        persona_state.state_data['context'] = new_context
      end

      Ai::PersonaFields.apply_updates(persona_state, updates)

      persona_state.save!
    end
  end
end
