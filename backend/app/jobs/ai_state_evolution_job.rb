class AiStateEvolutionJob < ApplicationJob
  include AiProviderConcern

  queue_as :default

  def perform(conversation_id)
    conversation = Conversation.find(conversation_id)
    return unless conversation.active?

    evolver = Ai::StateEvolver.new(default_ai_provider)
    recent_messages = conversation.recent_messages(15)

    evolver.evolve_from_conversation(conversation, recent_messages)

    Rails.logger.info "AI state evolved for conversation #{conversation_id}"

    execute_tools(conversation, recent_messages)

  rescue StandardError => e
    Rails.logger.error "AI state evolution failed: #{e.message}"
  end

  private

  def execute_tools(conversation, recent_messages)
    Persona::Tools::ToolExecutorService.execute(
      season: conversation.season,
      conversation: conversation,
      recent_messages: recent_messages
    )
  end
end
