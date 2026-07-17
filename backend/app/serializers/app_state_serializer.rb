class AppStateSerializer
  def self.build
    season = Season.current

    {
      version: Rails.application.config.app_version,
      season_number: season&.season_number || 0,
      active_users: Analytics::ActiveUsersService.count,
      total_users: Analytics::ActiveUsersService.total_users,
      has_active_season: season&.active? || false
    }
  end
end
