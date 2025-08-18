class Api::V1::BaseController < ApplicationController
  before_action :authenticate_api_key
  before_action :set_default_response_format
  before_action :check_rate_limit
  before_action :update_last_used

  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  
  private
  
  def authenticate_api_key
    api_key = request.headers['X-API-Key'] || params[:api_key]

    if api_key.blank?
      render_error('API key is required', :unauthorized)
      return
    end

    @current_app_profile = AppProfile.find_by(api_key_digest: BCrypt::Password.create(api_key))

    unless @current_app_profile
      render_error('Invalid API key', :unauthorized)
      return
    end
  end
  
  def set_default_response_format
    request.format = :json
  end
  
  def render_success(data, status: :ok, message: nil)
    response = {
      success: true,
      data: data
    }
    response[:message] = message if message
    
    render json: response, status: status
  end
  
  def render_error(message, status = :bad_request, errors: nil)
    response = {
      success: false,
      error: message
    }
    response[:errors] = errors if errors
    
    render json: response, status: status
  end
  
  def handle_standard_error(exception)
    Rails.logger.error "API Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    render_error('Internal server error', :internal_server_error)
  end
  
  def handle_not_found(exception)
    render_error('Resource not found', :not_found)
  end
  
  def handle_parameter_missing(exception)
    render_error("Missing required parameter: #{exception.param}", :bad_request)
  end

  def check_rate_limit
    return unless @current_app_profile

    # Simple rate limiting: 1000 requests per hour per API key
    cache_key = "rate_limit:#{@current_app_profile.id}"
    current_count = Rails.cache.read(cache_key) || 0

    if current_count >= 1000
      render_error('Rate limit exceeded. Maximum 1000 requests per hour.', :too_many_requests)
      return
    end

    Rails.cache.write(cache_key, current_count + 1, expires_in: 1.hour)
  end

  def update_last_used
    return unless @current_app_profile

    # Update the last used timestamp (but not on every request to avoid too many DB writes)
    last_update = Rails.cache.read("last_update:#{@current_app_profile.id}")
    if last_update.nil? || last_update < 5.minutes.ago
      @current_app_profile.touch(:updated_at)
      Rails.cache.write("last_update:#{@current_app_profile.id}", Time.current, expires_in: 5.minutes)
    end
  end
end
