module AiRouterConcern
  extend ActiveSupport::Concern

  private

  def ai_router
    @ai_router ||= AiProviders.build_router
  end
end
