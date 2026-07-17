module Ai
  module PersonaFields
    FIELDS = [
      { name: 'occupation', desc: 'updated occupation with VERY SPECIFIC details in Korean and REAL names - NO PLACEHOLDERS like ○○대학교 (e.g., 서울대학교 컴퓨터공학과 3학년 → 4학년 진급, 스타트업 마케팅 인턴 → 정규직 전환, 편의점 알바 → 카페 알바로 옮김). Use actual university/company names.', note: 'only if major change occurred' },
      { name: 'education', desc: 'updated education with VERY SPECIFIC details and REAL school names - NO PLACEHOLDERS (e.g., 연세대학교 경영학과 2학기 → 3학기, 대원외고 졸업 → 카이스트 입학, 토익 700점 → 850점). Always use real, specific school names.', note: 'only if semester/grade progressed' },
      { name: 'living_situation', desc: 'updated living situation with VERY SPECIFIC details and REAL location names - NO PLACEHOLDERS (e.g., 신촌 원룸 → 강남 오피스텔로 이사, 부모님 집 → 친구랑 홍대 투룸 합주, 기숙사 2인실 → 1인실로 변경). Use actual neighborhood/district names.', note: 'only if moved' },
      { name: 'economic_status', desc: 'updated financial situation with VERY SPECIFIC concrete details - NO PLACEHOLDERS (e.g., 편의점 알바 월 80만원 → 카페 알바 월 100만원, 부모님 용돈 50만원 → 100만원으로 증액, 학자금 대출 500만원 추가). Use real numbers and specific sources.', note: 'only if income changed' },
      { name: 'relationship_status', desc: 'updated relationship status (e.g., started dating, broke up)', note: 'only if relationship changed' },
      { name: 'personality_traits', item: 'trait', note: 'array of 2-3 traits in Korean if personality shifted, e.g., major life event shifted personality like ["내성적이고 신중함", "외향적이고 활발함"]' },
      { name: 'communication_style', item: 'style', note: 'array of communication styles in Korean if messaging habits evolved, e.g., ["이모티콘 자주 씀", "답장 빠름"]' },
      { name: 'interests', item: 'interest', note: 'array of 2-4 interests in Korean if hobbies changed, e.g., discovered new hobby like ["게임", "넷플릭스", "카페 투어"]' },
      { name: 'music_genres', item: 'genre', note: 'array of 2-5 music genres/artists in Korean if preferences changed, e.g., ["힙합 좋아함, 에픽하이 팬", "아이유, BTS 즐겨 들음"]' },
      { name: 'reading_habits', desc: 'updated reading habits', note: 'only if reading patterns changed' },
      { name: 'values', item: 'value', note: 'array of 2-3 values in Korean if life experiences shifted core values, e.g., ["가족", "자유", "성공"]' },
      { name: 'speech_patterns', item: 'pattern', note: 'array of speech patterns in Korean if communication style evolved, e.g., ["ㅋㅋ 자주 씀", "반말 편하게 함"]' },
      { name: 'background', desc: 'updated background', note: 'only if major life event occurred that changes personal history' },
      { name: 'energy_level', desc: 'updated energy level' },
      { name: 'health_status', desc: 'updated health status', note: 'only if health changed' },
      { name: 'physical_state', desc: 'updated physical state (e.g., got hungry, became tired, headache went away)' },
      { name: 'sleep_pattern', desc: 'updated sleep pattern', note: 'only if sleep habits changed' },
      { name: 'social_circle', item: 'circle', note: 'array of 2-4 social groups in Korean if new friends/groups added or lost, e.g., ["대학 동아리 친구들 5명", "고등학교 단짝 3명"]' },
      { name: 'family_structure', desc: 'updated family structure', note: 'only if family situation changed' },
      { name: 'birth_order', desc: 'updated birth order', note: 'RARELY changes, only if revealed new family info' },
      { name: 'sibling_dynamics', desc: 'updated sibling dynamics', note: 'if sibling relationships changed' },
      { name: 'parental_relationship_quality', desc: 'updated parental relationship', note: 'if relationship with parents changed' },
      { name: 'relationship_history', desc: 'updated relationship history', note: 'if new relationship events occurred' },
      { name: 'short_term_goals', item: 'goal', note: 'array of 2-4 immediate goals in Korean if goals completed, abandoned, or new ones formed, e.g., ["2025년 1학기 학점 3.5 이상", "토익 800점 넘기기"]' },
      { name: 'long_term_goals', item: 'goal', note: 'array of 1-3 life goals in Korean if life direction changed, e.g., ["대기업 취직", "30살 전에 결혼"]' },
      { name: 'current_worries', item: 'worry', note: 'array of 2-4 active concerns in Korean - worries can be resolved, new ones can emerge, e.g., ["취업 걱정", "학자금 대출 갚기"]' },
      { name: 'daily_routine', desc: 'updated daily routine', note: 'if schedule changed' },
      { name: 'conflict_style', desc: 'updated conflict handling style', note: 'if learned new approaches' },
      { name: 'decision_making_style', desc: 'updated decision making', note: 'if style evolved' },
      { name: 'stress_coping', desc: 'updated stress coping', note: 'if found new methods' },
      { name: 'attachment_style', desc: 'updated attachment style', note: 'if relationship patterns changed' },
      { name: 'food_preferences', desc: 'updated food preferences', note: 'if tastes changed' },
      { name: 'favorite_sounds', item: 'sound', note: 'if sound preferences changed' },
      { name: 'sensory_sensitivities', desc: 'updated sensitivities', note: 'if sensitivity levels changed' },
      { name: 'favorite_scents', item: 'scent', note: 'if scent preferences changed' },
      { name: 'humor_style', desc: 'updated humor style', note: 'if it evolved' },
      { name: 'media_currently_into', item: 'media', note: 'current media consumption changes frequently' },
      { name: 'skills', item: 'skill', note: 'if learned new skills or discovered lack of skills' },
      { name: 'insecurities', item: 'insecurity', note: 'insecurities can be revealed, overcome, or new ones can emerge' },
      { name: 'habits', item: 'habit', note: 'habits can be broken or new ones formed' },
      { name: 'nervous_tics', item: 'tic', note: 'if nervous behaviors changed' },
      { name: 'pet_peeves', item: 'peeve', note: 'if annoyances changed' },
      { name: 'cultural_identity', desc: 'updated cultural identity', note: 'only if cultural views evolved' },
      { name: 'pet_ownership', desc: 'updated pet situation', note: 'if got/lost pet or attitude changed' },
      { name: 'language_abilities', item: 'ability', note: 'if learned/improved language skills' },
      { name: 'political_social_views', desc: 'updated views', note: 'only if opinions shifted' },
      { name: 'religious_spiritual', desc: 'updated beliefs', note: 'only if spiritual journey changed' },
      { name: 'mental_health_state', desc: 'updated mental health', note: 'if mental state changed significantly' },
      { name: 'emotional_triggers', item: 'trigger', note: 'if new triggers discovered or old ones resolved' },
      { name: 'love_language', desc: 'updated love language', note: 'only if relationship style evolved' },
      { name: 'trust_level', desc: 'updated trust level', note: 'if trust in people changed' },
      { name: 'jealousy_tendency', desc: 'updated jealousy', note: 'only if jealousy patterns changed' },
      { name: 'risk_tolerance', desc: 'updated risk tolerance', note: 'only if risk-taking changed' },
      { name: 'personal_boundaries', item: 'boundary', note: 'if boundaries shifted' },
      { name: 'physical_appearance', desc: 'updated appearance feelings', note: 'if appearance or feelings changed' },
      { name: 'fashion_style', desc: 'updated fashion', note: 'only if style changed' },
      { name: 'exercise_habits', desc: 'updated exercise', note: 'if fitness routine changed' },
      { name: 'substance_use', desc: 'updated substance use', note: 'if drinking/smoking habits changed' },
      { name: 'allergies_restrictions', item: 'restriction', note: 'if new allergies discovered' },
      { name: 'cleanliness_organization', desc: 'updated cleanliness', note: 'only if tidiness changed' },
      { name: 'tech_savviness', desc: 'updated tech skills', note: 'if tech ability changed' },
      { name: 'social_media_usage', desc: 'updated social media', note: 'if SNS habits changed' },
      { name: 'specific_social_media_platforms', item: 'platform', note: 'if platform usage changed' },
      { name: 'online_vs_offline_persona', desc: 'updated online persona', note: 'if online behavior changed' },
      { name: 'phone_dependency', desc: 'updated phone dependency', note: 'if phone habits changed' },
      { name: 'time_management', desc: 'updated time management', note: 'only if punctuality changed' },
      { name: 'spending_habits', desc: 'updated spending', note: 'if money habits changed' },
      { name: 'learning_style', desc: 'updated learning style', note: 'only if learning approach changed' },
      { name: 'travel_history', item: 'place', note: 'if traveled somewhere new' },
      { name: 'significant_achievements', item: 'achievement', note: 'if achieved something notable' },
      { name: 'regrets', item: 'regret', note: 'if new regrets or resolved old ones' },
      { name: 'childhood_experiences', desc: 'updated childhood context', note: 'only if revealed new childhood info' },
      { name: 'trauma_history', desc: 'updated trauma', note: 'only if revealed new trauma or processed old trauma' },
      { name: 'secret_desires', item: 'desire', note: 'if desires changed or revealed' },
      { name: 'bucket_list', item: 'item', note: 'if bucket list items changed' },
      { name: 'role_models', item: 'model', note: 'if role models changed' },
      { name: 'phobias_fears', item: 'fear', note: 'if new fears discovered or overcame fears' },
      { name: 'comfort_activities', item: 'activity', note: 'if comfort activities changed' },
      { name: 'current_projects', item: 'project', note: 'if started/completed projects' },
      { name: 'recent_experiences', item: 'experience', note: 'this should update frequently with new experiences' },
      { name: 'current_location_detail', desc: 'updated location', note: 'if location changed' },
      { name: 'weather_mood_correlation', desc: 'updated weather-mood link', note: 'only if relationship with weather changed' },
      { name: 'favorite_season', desc: 'updated favorite season', note: 'if seasonal preferences changed' },
      { name: 'preferred_temperature_range', desc: 'updated temperature preference', note: 'if temperature comfort changed' },
      { name: 'friendship_style', desc: 'updated friendship style', note: 'only if friendship approach changed' },
      { name: 'response_to_compliments', desc: 'updated response to praise', note: 'if reaction to compliments changed' },
      { name: 'response_to_criticism', desc: 'updated response to criticism', note: 'if reaction to feedback changed' },
      { name: 'gift_giving_style', desc: 'updated gift giving', note: 'if gift habits changed' },
      { name: 'gift_receiving_comfort', desc: 'updated gift receiving comfort', note: 'if comfort with gifts changed' },
      { name: 'conversation_energy', desc: 'updated social battery', note: 'if conversation energy changed' },
      { name: 'small_talk_ability', desc: 'updated small talk ability', note: 'if chitchat skills changed' },
      { name: 'apology_style', desc: 'updated apology style', note: 'if apology patterns changed' },
      { name: 'superstitions', item: 'superstition', note: 'if beliefs/rituals changed' },
      { name: 'conflict_history', desc: 'updated conflict history', note: 'if had new conflict or resolved old ones' },
      { name: 'support_system', item: 'support', note: 'if support system changed' }
    ].freeze

    FIELD_NAMES = FIELDS.map { |field| field[:name] }.freeze

    module_function

    def schema_lines(indent: '  ')
      FIELDS.map { |field| "#{indent}#{render_field(field)}" }.join("\n")
    end

    def array_field_names
      FIELDS.select { |field| field[:item] }.map { |field| field[:name] }
    end

    def critical_data_guidelines
      <<~GUIDELINES.chomp
        CRITICAL: When updating any fields, always use REAL, SPECIFIC names and details. NEVER use placeholders like ○○대학교, ○○회사, ○○동, etc.

        CRITICAL: When referencing time, always use ABSOLUTE dates/times (e.g., "2025년 11월 9일", "오후 3시") instead of relative references (e.g., "오늘", "어제", "며칠 전", "몇 시간 전").
      GUIDELINES
    end

    def apply_updates(persona_state, updates, allow: [])
      return if updates.blank?

      allowed = FIELD_NAMES + allow

      updates.each do |key, value|
        next if value.nil?
        next unless allowed.include?(key)

        persona_state.state_data[key] = value
      end
    end

    def render_field(field)
      value = if field[:item]
        %(["#{field[:item]}1", "#{field[:item]}2"])
      else
        %("#{field[:desc]}")
      end
      note = field[:note] ? " (#{field[:note]})" : ''
      %("#{field[:name]}": #{value} or null#{note},)
    end
  end
end
