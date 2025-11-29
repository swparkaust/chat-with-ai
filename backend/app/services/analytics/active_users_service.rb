module Analytics
  class ActiveUsersService
    def self.count(timeframe: 24.hours)
      User.where('last_seen_at > ?', timeframe.ago).count
    end

    def self.currently_online
      User.where('last_seen_at > ?', 5.minutes.ago).count
    end

    def self.active_in_season(season)
      season.conversations
            .joins(:user)
            .where('users.last_seen_at > ?', 24.hours.ago)
            .distinct
            .count
    end

    def self.total_users
      User.count
    end

    def self.broadcast_active_count
      count = count(timeframe: 24.hours)

      ActionCable.server.broadcast(
        'app_state',
        {
          type: 'active_users_update',
          count: count
        }
      )
    end
  end
end
