module Memory
  class ManagementService
    MIN_MEMORIES_FOR_CONSOLIDATION = 15
    MAX_MEMORIES_BEFORE_PRUNING = 50
    SIMILARITY_THRESHOLD = 40.0  # Minimum similarity % for consolidation
    MIN_AGE_FOR_CONSOLIDATION_DAYS = 14
    MIN_DETAIL_FOR_PROTECTION = 0.7
    MIN_SIGNIFICANCE_FOR_PROTECTION = 6.5

    def initialize(season)
      @season = season
      @memories = season.persona_memories
    end

    def apply_decay_to_all
      return 0 if @memories.empty?

      decay_count = 0
      significant_decays = []

      @memories.each do |memory|
        old_detail = memory.detail_level
        decayed = memory.apply_decay!

        if decayed && (old_detail - memory.detail_level).abs > 0.15
          significant_decays << {
            memory: memory,
            old_detail: old_detail,
            new_detail: memory.detail_level,
            age_days: memory.age_in_days
          }
          decay_count += 1
        end
      end

      if significant_decays.any?
        Rails.logger.info "Memory decay applied: #{decay_count} memories significantly decayed"
      end

      decay_count
    end

    def consolidate_memories
      return 0 if @memories.count < MIN_MEMORIES_FOR_CONSOLIDATION

      Rails.logger.info "Checking for memories to consolidate (total: #{@memories.count})"

      consolidated_count = 0
      to_remove = Set.new
      new_consolidated_memories = []

      @memories.each_with_index do |memory1, i|
        next if to_remove.include?(memory1.id)
        next if !consolidatable?(memory1)

        related_memories = find_related_memories(memory1, to_remove)
        next if related_memories.empty?

        consolidated = create_consolidated_memory(memory1, related_memories)
        new_consolidated_memories << consolidated

        to_remove.add(memory1.id)
        related_memories.each { |m| to_remove.add(m.id) }

        consolidated_count += 1
      end

      if consolidated_count > 0
        PersonaMemory.where(id: to_remove.to_a).destroy_all
        new_consolidated_memories.each(&:save!)

        Rails.logger.info "Consolidated #{to_remove.size} old memories into #{consolidated_count} summary memories"
      else
        Rails.logger.info "No memories consolidated (not enough related old memories)"
      end

      consolidated_count
    end

    def prune_memories
      return 0 if @memories.count <= MAX_MEMORIES_BEFORE_PRUNING

      scored_memories = @memories.map do |memory|
        [memory, memory.pruning_score]
      end.sort_by { |_, score| score }

      to_prune = scored_memories.first(@memories.count - MAX_MEMORIES_BEFORE_PRUNING)
      prune_count = to_prune.length

      if prune_count > 0
        Rails.logger.info "Pruning #{prune_count} lowest-scoring memories (current total: #{@memories.count})"

        to_prune.each do |memory, score|
          memory.destroy!
        end

        Rails.logger.info "After pruning: #{@memories.count - prune_count} memories remaining"
      end

      prune_count
    end

    def memories_by_importance
      @memories.sort_by { |m| -m.pruning_score }
    end

    private

    def consolidatable?(memory)
      memory.age_in_days >= MIN_AGE_FOR_CONSOLIDATION_DAYS &&
        memory.detail_level <= MIN_DETAIL_FOR_PROTECTION &&
        memory.significance < MIN_SIGNIFICANCE_FOR_PROTECTION
    end

    def find_related_memories(memory, excluded_ids)
      related = []

      @memories.each do |other_memory|
        next if other_memory.id == memory.id
        next if excluded_ids.include?(other_memory.id)
        next unless consolidatable?(other_memory)

        similarity = memory.similarity_to(other_memory)
        related << other_memory if similarity >= SIMILARITY_THRESHOLD
      end

      related
    end

    def create_consolidated_memory(primary_memory, related_memories)
      all_memories = [primary_memory] + related_memories
      all_tags = all_memories.flat_map(&:tags).uniq

      tag_counts = all_tags.each_with_object(Hash.new(0)) do |tag, counts|
        all_memories.each { |m| counts[tag] += 1 if m.tags.include?(tag) }
      end
      top_tags = tag_counts.sort_by { |_, count| -count }.first(3).map(&:first)

      consolidated_content = "#{all_memories.length}개의 관련된 기억들 (주제: #{top_tags.join(', ')})"

      avg_significance = all_memories.sum(&:significance) / all_memories.length.to_f
      avg_emotional_intensity = all_memories.sum(&:emotional_intensity) / all_memories.length.to_f
      avg_detail_level = all_memories.sum(&:detail_level) / all_memories.length.to_f

      PersonaMemory.new(
        season: @season,
        content: consolidated_content,
        memory_timestamp: primary_memory.memory_timestamp,
        significance: avg_significance,
        emotional_intensity: avg_emotional_intensity,
        detail_level: avg_detail_level,
        tags: top_tags,
        recall_count: 0
      )
    end
  end
end
