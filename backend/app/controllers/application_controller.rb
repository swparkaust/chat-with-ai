class ApplicationController < ActionController::API
  before_action :set_current_user

  rescue_from StandardError, with: :handle_internal_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

  attr_reader :current_user

  private

  def set_current_user
    device_id = request.headers['X-Device-ID']
    @current_user = User.find_by(device_id: device_id) if device_id.present?
  end

  def authenticate_user!
    unless current_user
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def handle_internal_error(error)
    log_error(error, :error, :internal_server_error)
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  def handle_not_found(error)
    log_error(error, :warn, :not_found)
    render json: { error: 'Resource not found' }, status: :not_found
  end

  def handle_validation_error(error)
    log_error(error, :warn, :unprocessable_entity)
    render json: {
      error: 'Validation failed',
      details: error.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def handle_parameter_missing(error)
    log_error(error, :warn, :bad_request)
    render json: {
      error: 'Missing required parameter',
      parameter: error.param
    }, status: :bad_request
  end

  def log_error(error, level, status)
    Rails.logger.public_send(level, {
      controller: self.class.name,
      action: action_name,
      error_class: error.class.name,
      error_message: error.message,
      status: status,
      params: request.params.except(:controller, :action, :format),
      user_id: current_user&.id,
      device_id: request.headers['X-Device-ID'],
      backtrace: error.backtrace&.first(5)
    }.to_json)
  end
end
