# Application configuration
Rails.application.config.app_version = ENV.fetch('APP_VERSION', '1.0.0')

# Configure periodic tasks
Rails.application.config.after_initialize do
  # Start periodic tasks job (runs every hour)
  PeriodicTasksJob.set(wait: 10.seconds).perform_later
end
