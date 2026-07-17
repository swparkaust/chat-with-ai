class AiStateEvolutionJob < ApplicationJob
  include AiRouterConcern

  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    return unless conversation.active?

    evolver = Ai::StateEvolver.new(router: ai_router)
    recent_messages = conversation.recent_messages(15)

    evolver.evolve_from_conversation(conversation, recent_messages)

    Rails.logger.info "AI state evolved for conversation #{conversation_id}"

    # StateEvolver and ToolExecutorService rescue internally (graceful
    # degradation — the next chain evolves fresh state), so the class-level
    # retry policies only cover loading. Lifting those rescues needs
    # idempotency first: apply_updates creates PersonaMemory rows.
    Persona::Tools::ToolExecutorService.execute(
      season: conversation.season,
      conversation: conversation,
      recent_messages: recent_messages,
      router: ai_router
    )
  end
end
