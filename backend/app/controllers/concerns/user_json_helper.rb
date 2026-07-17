module UserJsonHelper
  extend ActiveSupport::Concern

  private

  def user_json(user)
    user.as_json(only: [:id, :device_id, :name, :status_message]).merge(
      profile_picture: AttachmentUrl.for(user.profile_picture)
    )
  end
end
