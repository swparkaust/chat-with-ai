class NaturalEvolutionJob < ApplicationJob
  include AiProviderConcern

  queue_as :default

  def perform
    season = Season.current
    return unless season&.persona_state

    evolver = Ai::NaturalEvolver.new(default_ai_provider)

    evolver.evolve_naturally(season.persona_state)

    execute_tools(season)
  rescue StandardError => e
    Rails.logger.error "Natural evolution job failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def execute_tools(season)
    Persona::Tools::ToolExecutorService.execute(
      season: season,
      context_description: 'during natural evolution'
    )
  end
end
