module ProfileUpdatable
  extend ActiveSupport::Concern
  include InputSanitization

  private

  def apply_profile_update(param_key)
    attrs = params.require(param_key)

    if attrs[:profile_picture_signed_id].present?
      begin
        blob = ActiveStorage::Blob.find_signed(attrs[:profile_picture_signed_id])
        current_user.profile_picture.attach(blob)
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Upload token expired or invalid, please try again' }, status: :bad_request
        return false
      end
    end

    sanitized_params = {}
    sanitized_params[:name] = sanitize_content(attrs[:name]) if attrs[:name].present?
    sanitized_params[:status_message] = sanitize_content(attrs[:status_message]) if attrs[:status_message].present?

    if current_user.update(sanitized_params)
      true
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
      false
    end
  end
end
