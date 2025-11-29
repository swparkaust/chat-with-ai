class PeriodicTasksJob < ApplicationJob
  queue_as :default

  def perform
    SeasonRotationJob.perform_later
    SeasonDeactivationReminderJob.perform_later
    ActiveUsersUpdateJob.perform_later
    NaturalEvolutionJob.perform_later
    MemoryManagementJob.perform_later

    check_tool_triggers

    PeriodicTasksJob.set(wait: 1.hour).perform_later
  end

  private

  def check_tool_triggers
    current_season = Season.current
    return unless current_season

    tool_manager = Persona::Tools::ToolManager.new(current_season)
    triggers = tool_manager.check_all_triggers

    if triggers.any?
      Rails.logger.info "Tool triggers fired: #{triggers.inspect}"
    end
  end
end
