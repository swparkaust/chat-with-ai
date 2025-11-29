class ApplicationJob < ActiveJob::Base
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3

  discard_on ActiveJob::DeserializationError

  discard_on ActiveRecord::RecordNotFound do |job, error|
    log_job_error(job, error, :warn, discarded: true)
  end

  retry_on Ai::BaseProvider::Error, wait: :exponentially_longer, attempts: 3 do |job, error|
    log_job_error(job, error, :warn, retrying: true)
  end

  retry_on StandardError, wait: 30.seconds, attempts: 2 do |job, error|
    log_job_error(job, error, :error, retrying: true)
  end

  private

  def self.log_job_error(job, error, level, **context)
    Rails.logger.public_send(level, {
      job: job.class.name,
      job_id: job.job_id,
      queue: job.queue_name,
      error_class: error.class.name,
      error_message: error.message,
      arguments: job.arguments,
      executions: job.executions,
      context: context,
      backtrace: error.backtrace&.first(10)
    }.to_json)
  end

  def log_error(error, level = :error, **context)
    self.class.log_job_error(self, error, level, **context)
  end
end
