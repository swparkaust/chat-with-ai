module SeasonServices
  class RotationManagerService
    ROTATION_LOCK_KEY = "season:rotation:lock"

    def self.check_and_rotate
      DistributedLockManager.with_lock(ROTATION_LOCK_KEY, ttl: 600) do
        current_season = ::Season.current

        return unless current_season
        return unless current_season.should_rotate?

        Rails.logger.info "Rotating season #{current_season.season_number}"

        new_season = rotate_season(current_season)

        notify_users_of_rotation(new_season)

        new_season
      end
    end

    def self.rotate_season(current_season)
      ::Season.transaction do
        current_season.deactivate!

        new_season = ::Season.create!(
          active: false,
          start_date: Time.current
        )

        initialize_persona(new_season)

        new_season.update!(active: true)

        new_season
      end
    end

    def self.initialize_persona(season, prompt: nil)
      prompt ||= generate_random_prompt

      provider = Ai::ProviderFactory.default

      generator = Ai::PersonaGenerator.new(provider)
      result = generator.generate(prompt)

      persona_state = season.persona_state
      persona_state.update!(state_data: result[:state_data])

      result[:memories].each do |memory_data|
        season.persona_memories.create!(
          content: memory_data['content'],
          significance: memory_data['significance'],
          emotional_intensity: memory_data['emotional_intensity'],
          tags: memory_data['tags'] || [],
          memory_timestamp: Time.current
        )
      end

      season.update!(
        first_name: result[:first_name],
        last_name: result[:last_name],
        status_message: result[:status_message]
      )

      Rails.logger.info "Persona initialized: #{season.full_name}"

      initialize_tools(season, provider)

      true
    end

    def self.initialize_tools(season, provider)
      tool_manager = Persona::Tools::ToolManager.new(season)
      system_context = Ai::SystemContextBuilder.new(season.persona_state, nil).build

      results = tool_manager.execute_tool_chain(provider, system_context, "")

      if results.any?
        Rails.logger.info "Initialized tools with #{results.count} initial actions"
      end
    rescue StandardError => e
      Rails.logger.error "Tool initialization failed: #{e.message}"
    end

    private

    def self.generate_random_prompt
      ages = ['20대 초반', '20대 중반', '20대 후반']
      genders = ['남자', '여자']
      occupations = ['대학생', '직장인', '프리랜서', '취업준비생']
      personalities = ['활발한', '조용한', '유머러스한', '진지한', '낭만적인']

      age = ages.sample
      gender = genders.sample
      occupation = occupations.sample
      personality = personalities.sample

      "#{age} #{occupation} #{gender}, #{personality} 성격"
    end

    def self.notify_users_of_rotation(new_season)
      ActionCable.server.broadcast(
        'app_state',
        {
          type: 'season_rotated',
          new_season: {
            id: new_season.id,
            season_number: new_season.season_number,
            first_name: new_season.first_name
          }
        }
      )
    end
  end
end
