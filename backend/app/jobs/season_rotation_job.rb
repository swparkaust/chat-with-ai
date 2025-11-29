class SeasonRotationJob < ApplicationJob
  queue_as :default

  def perform
    SeasonServices::RotationManagerService.check_and_rotate
  rescue StandardError => e
    Rails.logger.error "Season rotation failed: #{e.message}"
  end
end
