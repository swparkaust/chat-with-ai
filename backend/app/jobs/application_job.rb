class ApplicationJob < ActiveJob::Base
  # Handler precedence is reverse declaration order (last declared wins), so
  # the generic StandardError handler MUST be declared first and the specific
  # handlers after it — otherwise it shadows them all. AI-pipeline jobs
  # replace this whole stack via ai_pipeline_retry below.
  #
  # NOTE: retry_on blocks run on retry EXHAUSTION (the error is swallowed,
  # not re-raised), so these are last-stop logs, not per-retry logs
  retry_on StandardError, wait: 30.seconds, attempts: 2 do |job, error|
    log_job_error(job, error, :error, retries_exhausted: true)
  end

  retry_on Ai::GenerationError, wait: :polynomially_longer, attempts: 3 do |job, error|
    log_job_error(job, error, :warn, retries_exhausted: true)
  end

  # Log-then-re-raise: three fixed 5s attempts often land inside the same
  # contention burst, so escalate to Sidekiq's exponential backoff (which
  # clears it) while keeping exhaustion visible in the structured stream
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3 do |job, error|
    log_job_error(job, error, :error, retries_exhausted: true)
    raise error
  end

  discard_on ActiveJob::DeserializationError

  discard_on ActiveRecord::RecordNotFound do |job, error|
    log_job_error(job, error, :warn, discarded: true)
  end

  # The full retry/discard stack for AI-pipeline jobs (first positional arg =
  # conversation id; kwargs may carry lock_token), declared once in correct
  # precedence order so per-job declarations can't hit the shadowing trap.
  # The continuation runs with (conversation_id, options) after exhaustion.
  # These retry waits are budgeted against DistributedLockManager::DEFAULT_TTL
  # by FragmentSendJob's keep-lock strategy — tune together.
  #
  # Deliberately no terminal state beyond RecordNotFound: persistent failure
  # cycles through spaced continuations, surfacing as log volume rather than
  # a silently dead conversation.
  def self.ai_pipeline_retry(release_lock: false, &continuation)
    handle_exhaustion = lambda do |job, error, level|
      log_job_error(job, error, level, retries_exhausted: true)
      # Best-effort: a raise escaping this block goes to the adapter's own
      # retry, re-executing a job whose lock was already released. Lost
      # cleanup is recovered by the hourly nets (see finalize_sending).
      begin
        release_job_lock(job) if release_lock
        continuation.call(*extract_job_args(job))
      rescue StandardError => e
        Rails.logger.error "#{job.class.name}: exhaustion cleanup failed: #{e.message}"
      end
    end

    retry_on StandardError, wait: 30.seconds, attempts: 2 do |job, error|
      handle_exhaustion.call(job, error, :error)
    end

    retry_on Ai::GenerationError, wait: :polynomially_longer, attempts: 3 do |job, error|
      handle_exhaustion.call(job, error, :warn)
    end

    retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3 do |job, error|
      handle_exhaustion.call(job, error, :error)
    end

    discard_on ActiveJob::DeserializationError

    discard_on ActiveRecord::RecordNotFound do |job, error|
      log_job_error(job, error, :warn, discarded: true)
      # Best-effort like handle_exhaustion: a raise from a discard block
      # sends the should-be-discarded job to the adapter's retry cycle
      begin
        release_job_lock(job) if release_lock
      rescue StandardError => e
        Rails.logger.error "#{job.class.name}: discard cleanup failed: #{e.message}"
      end
    end
  end

  # [conversation_id, options] from an AI-pipeline job's serialized arguments
  def self.extract_job_args(job)
    options = job.arguments.last.is_a?(Hash) ? job.arguments.last : {}
    [job.arguments.first, options]
  end

  # Release the ai_decision lock from serialized arguments (exhaustion and
  # discard handlers can't use instance state)
  def self.release_job_lock(job)
    conversation_id, options = extract_job_args(job)
    DistributedLockManager.release(DistributedLockManager.ai_decision_key(conversation_id), options[:lock_token])
  end

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

end
