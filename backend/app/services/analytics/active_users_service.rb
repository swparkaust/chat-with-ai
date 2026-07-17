module Analytics
  class ActiveUsersService
    def self.count(timeframe: AppConstants::ACTIVE_USER_WINDOW)
      User.where('last_seen_at > ?', timeframe.ago).count
    end

    def self.total_users
      User.count
    end

    def self.broadcast_active_count
      ActionCable.server.broadcast(
        'app_state',
        { type: 'active_users_update' }.merge(AppStateSerializer.build)
      )
    end
  end
end
