module SeasonServices
  class RotationManagerService
    ROTATION_LOCK_KEY = "season:rotation:lock"

    def self.check_and_rotate
      # The lock is never refreshed mid-rotation, so the real invariant is
      # "a rotation completes within this TTL" (generation + tool init:
      # several external AI/web calls, minutes under retries). A rotation
      # hung past it could overlap the next hourly sweep — bounded by the
      # at-most-one-active DB index and the unnamed-husk sweep.
      DistributedLockManager.with_lock(ROTATION_LOCK_KEY, ttl: 1800) do
        current_season = ::Season.current

        return unless current_season
        return unless current_season.should_rotate?

        Rails.logger.info "Rotating season #{current_season.season_number}"

        new_season = rotate_season

        notify_users_of_rotation

        new_season
      end
    end

    def self.rotate_season
      # Persona generation (minutes of external AI/web calls) must not run
      # inside a DB transaction, and the OLD season must stay active until
      # the successor is fully ready — a failed attempt then leaves a
      # rotatable current season for the next hourly sweep to retry. The
      # rescue covers everything through activation so any failure removes
      # the partially-built row; unnamed husks from hard kills (no exception
      # ever fires) are swept on the next attempt.
      destroy_unnamed_husks

      new_season = ::Season.create!(active: false, start_date: Time.current)

      begin
        initialize_persona(new_season)

        ::Season.transaction do
          ::Season.current&.deactivate!
          new_season.update!(active: true)
        end
      rescue StandardError
        # Best-effort cleanup: a destroy failure must not mask the original
        # error (the unnamed-husk sweep catches the leftover next attempt)
        begin
          new_season.destroy!
        rescue StandardError => cleanup_error
          Rails.logger.error "Failed to clean up season after rotation failure: #{cleanup_error.message}"
        end
        raise
      end

      new_season
    end

    # Inactive seasons that never received a persona name are residue from a
    # crashed generation attempt (real deactivated seasons are always named);
    # they inflate max(season_number) and would create user-visible gaps
    def self.destroy_unnamed_husks
      ::Season.where(active: false, first_name: nil).destroy_all
    end

    def self.initialize_persona(season, prompt: nil)
      prompt ||= generate_random_prompt

      router = AiProviders.build_router

      generator = Ai::PersonaGenerator.new(router: router)
      result = generator.generate(prompt)

      persona_state = season.persona_state
      persona_state.update!(state_data: result[:state_data])

      result[:memories].each do |memory_data|
        PersonaMemory.create_from_ai!(season, memory_data)
      end

      season.update!(
        first_name: result[:first_name],
        last_name: result[:last_name],
        status_message: result[:status_message]
      )

      Rails.logger.info "Persona initialized: #{season.full_name}"

      initialize_tools(season, router)

      true
    end

    def self.initialize_tools(season, router)
      tool_manager = Persona::Tools::ToolManager.new(season)
      system_context = Ai::SystemContextBuilder.new(season.persona_state, nil).build

      results = tool_manager.execute_tool_chain(router, system_context, "")

      if results.any?
        Rails.logger.info "Initialized tools with #{results.count} initial actions"
      end
    rescue StandardError => e
      Rails.logger.error "Tool initialization failed: #{e.message}"
    end

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

    def self.notify_users_of_rotation
      ActionCable.server.broadcast('app_state', { type: 'season_rotated' })
    end

    # `private` has no effect on singleton methods; this is the working form
    private_class_method :generate_random_prompt, :notify_users_of_rotation
  end
end
