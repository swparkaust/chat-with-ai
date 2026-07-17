module SeasonServices
  class DeactivationNotifierService
    def self.check_and_notify
      current_season = ::Season.current

      return unless current_season
      return unless current_season.should_warn_deactivation?

      Rails.logger.info "Sending deactivation warning for season #{current_season.season_number}"

      send_deactivation_messages(current_season)
      current_season.mark_deactivation_warned!

      true
    end

    def self.send_deactivation_messages(season)
      season.conversations.active_conversations.find_each do |conversation|
        SeasonFarewellJob.perform_later(conversation.id)
      end
    end
  end
end
