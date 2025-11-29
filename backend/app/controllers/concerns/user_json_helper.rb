module UserJsonHelper
  extend ActiveSupport::Concern

  private

  def user_json(user)
    user.as_json(only: [:id, :device_id, :name, :status_message]).merge(
      profile_picture: user.profile_picture.attached? ? url_for(user.profile_picture) : nil
    )
  end
end
