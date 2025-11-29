class ActiveUsersUpdateJob < ApplicationJob
  queue_as :default

  def perform
    Analytics::ActiveUsersService.broadcast_active_count
  rescue StandardError => e
    Rails.logger.error "Active users update failed: #{e.message}"
  end
end
