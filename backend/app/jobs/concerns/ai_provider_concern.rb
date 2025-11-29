module AiProviderConcern
  extend ActiveSupport::Concern

  private

  def default_ai_provider
    Ai::ProviderFactory.default
  end
end
