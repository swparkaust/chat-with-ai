class AppStateChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'app_state'

    Rails.logger.info "User subscribed to app_state channel"

    transmit({
      type: 'initial_state',
      season_number: Season.current&.season_number,
      active_users: Analytics::ActiveUsersService.count,
      version: Rails.application.config.app_version || '1.0.0'
    })
  end

  def unsubscribed
    Rails.logger.info "User unsubscribed from app_state channel"
  end
end
