module Api
  module V1
    class AppStateController < ApplicationController
      def show
        season = Season.current
        version = Rails.application.config.app_version || '1.0.0'
        active_users = Analytics::ActiveUsersService.count

        render json: {
          app_state: {
            version: version,
            season_number: season&.season_number || 0,
            active_users: active_users,
            total_users: User.count,
            has_active_season: season&.active? || false
          }
        }
      end
    end
  end
end
