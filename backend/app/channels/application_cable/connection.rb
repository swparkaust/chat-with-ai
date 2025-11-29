module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
      Rails.logger.info "ActionCable connected: User #{current_user.id}"
    end

    private

    def find_verified_user
      device_id = request.params[:device_id]

      if device_id.present? && (user = User.find_by(device_id: device_id))
        user.touch_last_seen
        user
      else
        reject_unauthorized_connection
      end
    end
  end
end
