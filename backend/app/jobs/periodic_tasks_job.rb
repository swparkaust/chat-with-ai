class PeriodicTasksJob < ApplicationJob
  SCHEDULE_LOCK_KEY = 'periodic_tasks:scheduled'
  RESCHEDULE_INTERVAL = 1.hour
  # Must exceed the longest gap between a direct upload and its attach —
  # in-flight profile saves and any console-prepared blob have to complete
  # within this window or the sweep purges them
  UNATTACHED_BLOB_RETENTION = 1.day

  queue_as :default

  # Enqueue the next run only if no run is already scheduled — every process
  # boot calls this, and without the guard each boot would spawn another
  # perpetual hourly chain. The lock expires just before the scheduled run so
  # the chain can re-acquire it, and a lost chain self-heals on the next boot.
  def self.schedule(wait: RESCHEDULE_INTERVAL)
    ttl = [wait.to_i - 5, 5].max
    set(wait: wait).perform_later if DistributedLockManager.acquire(SCHEDULE_LOCK_KEY, ttl: ttl)
  end

  def perform
    self.class.schedule

    SeasonRotationJob.perform_later
    SeasonDeactivationReminderJob.perform_later
    ActiveUsersUpdateJob.perform_later
    NaturalEvolutionJob.perform_later
    MemoryManagementJob.perform_later

    # RECOVERY NETS — load-bearing, not routine maintenance: the pipeline's
    # best-effort posture (finalize_sending and ai_pipeline_retry swallow
    # post-release failures) assumes these run every RESCHEDULE_INTERVAL.
    # Removing, gating, or starving them turns swallowed enqueue blips into
    # permanently silenced conversations and lost farewells.
    SeasonFarewellJob.resend_missing(Season.current)
    AiDecisionJob.revive_all(Season.current)

    check_tool_triggers
    purge_unattached_blobs
  end

  private

  # Profile pictures are uploaded direct-to-blob before the profile update
  # attaches them, so a failed or abandoned save strands an unattached blob.
  # Sweep ones old enough that no in-flight save can still claim them.
  def purge_unattached_blobs
    ActiveStorage::Blob.unattached
                       .where(active_storage_blobs: { created_at: ..UNATTACHED_BLOB_RETENTION.ago })
                       .find_each(&:purge_later)
  end

  def check_tool_triggers
    current_season = Season.current
    return unless current_season

    # Accepted residual: this sweep persists trigger consumption (one-shot
    # completion, calendar/birthday fire-once marks) BEFORE the single
    # rescue-wrapped AI call below, so a provider outage in this run drops
    # those firings. Two-phase commit was judged disproportionate.
    tool_manager = Persona::Tools::ToolManager.new(current_season)
    triggers = tool_manager.check_all_triggers
    return if triggers.empty?

    Rails.logger.info "Tool triggers fired: #{triggers.inspect}"

    Persona::Tools::ToolExecutorService.execute(
      season: current_season,
      context_description: 'for periodic tool triggers',
      triggers: triggers
    )

    # Fired triggers are conversation-agnostic strings, so wake every active
    # conversation's parked decision loop — each persona decides for itself
    # whether the trigger warrants action (it may just wait). Runs AFTER the
    # executor so the internal reaction (diary/memo writes) is visible to
    # the woken decisions. restart_chain is best-effort and never raises.
    current_season.conversations.active_conversations.find_each do |conversation|
      AiDecisionJob.restart_chain(conversation.id, jitter: true)
    end
  end
end
