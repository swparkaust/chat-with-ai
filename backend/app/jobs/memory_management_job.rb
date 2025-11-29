class MemoryManagementJob < ApplicationJob
  queue_as :default

  def perform
    current_season = Season.current
    return unless current_season&.active?

    Rails.logger.info "Running memory management for Season #{current_season.season_number}"

    service = Memory::ManagementService.new(current_season)

    decay_count = service.apply_decay_to_all
    Rails.logger.info "Memory decay complete: #{decay_count} memories decayed"

    consolidated_count = service.consolidate_memories
    Rails.logger.info "Memory consolidation complete: #{consolidated_count} groups consolidated"

    pruned_count = service.prune_memories
    Rails.logger.info "Memory pruning complete: #{pruned_count} memories pruned"

    total_memories = current_season.persona_memories.count
    Rails.logger.info "Memory management complete. Total memories: #{total_memories}"

  rescue StandardError => e
    Rails.logger.error "Memory management failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
