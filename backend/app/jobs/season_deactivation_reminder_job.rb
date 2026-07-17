class SeasonDeactivationReminderJob < ApplicationJob
  queue_as :default

  def perform
    SeasonServices::DeactivationNotifierService.check_and_notify
  rescue StandardError => e
    Rails.logger.error "Season deactivation reminder failed: #{e.message}"
  end
end
