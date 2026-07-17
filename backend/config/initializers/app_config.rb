# Application configuration
Rails.application.config.app_version = ENV.fetch('APP_VERSION', '1.0.0')

# Configure periodic tasks
Rails.application.config.after_initialize do
  # Start the hourly periodic tasks chain. The schedule guard dedups boots
  # within the wait window, so use a wait comfortably longer than the gap
  # between web and worker processes booting.
  PeriodicTasksJob.schedule(wait: 30.seconds)
end
