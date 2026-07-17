class AppStateChannel < ApplicationCable::Channel
  def subscribed
    stream_from 'app_state'

    Rails.logger.info "User subscribed to app_state channel"

    transmit({ type: 'initial_state' }.merge(AppStateSerializer.build))
  end

  def unsubscribed
    Rails.logger.info "User unsubscribed from app_state channel"
  end
end
