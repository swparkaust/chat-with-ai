class AiModelRouter
  TASK_TIERS = {
    persona_generation: :advanced,
    message_generation: :advanced,
    conversation_initiation: :advanced,
    farewell_generation: :advanced,
    action_decision: :standard,
    thinking_timing: :standard,
    fragment_timing: :standard,
    # :advanced — reevaluation can rewrite user-visible fragments authored by
    # the advanced tier; a cheaper model here would splice a mid-message
    # quality seam into the persona's voice
    fragment_reevaluation: :advanced,
    state_evolution: :standard,
    natural_evolution: :standard,
    tool_execution: :standard
  }.freeze

  def initialize(provider:, model_map:)
    @provider = provider
    @model_map = model_map
  end

  def call(task:, system:, prompt:, max_tokens: AppConstants::AI_MAX_OUTPUT_TOKENS)
    tier = TASK_TIERS.fetch(task) do
      raise ArgumentError, "Unknown AI task: #{task}. Known tasks: #{TASK_TIERS.keys.join(', ')}"
    end

    model = @model_map.fetch(tier)

    response = @provider.complete(
      model: model,
      system: system,
      prompt: prompt,
      max_tokens: max_tokens
    )

    AiResponse.new(
      text: response.text,
      model: response.model,
      provider: response.provider,
      task: task
    )
  end
end
