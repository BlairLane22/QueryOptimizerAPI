class Api::V1::ApiKeysController < Api::V1::BaseController
  skip_before_action :authenticate_api_key, only: [:create]
  
  def create
    if params[:app_name].nil?
      render_error('Missing required parameter: app_name')
      return
    end

    app_name = params[:app_name]

    if app_name.blank?
      render_error('App name is required')
      return
    end
    
    if app_name.length < 3 || app_name.length > 100
      render_error('App name must be between 3 and 100 characters')
      return
    end
    
    # Check if app name already exists
    if AppProfile.exists?(name: app_name)
      render_error('App name already exists')
      return
    end
    
    app_profile = AppProfile.new(name: app_name)
    api_key = app_profile.generate_api_key!
    
    if app_profile.persisted?
      render_success({
        app_name: app_profile.name,
        api_key: api_key,
        created_at: app_profile.created_at.iso8601
      }, message: 'API key created successfully')
    else
      render_error('Failed to create API key', :internal_server_error)
    end
  rescue ActionController::ParameterMissing => e
    render_error("Missing required parameter: #{e.param}")
  end
  
  def show
    render_success({
      app_name: @current_app_profile.name,
      created_at: @current_app_profile.created_at.iso8601,
      last_used: @current_app_profile.updated_at.iso8601,
      total_queries: @current_app_profile.query_analyses.count
    })
  end
  
  def regenerate
    begin
      new_api_key = @current_app_profile.generate_api_key!
      
      render_success({
        app_name: @current_app_profile.name,
        api_key: new_api_key,
        regenerated_at: Time.current.iso8601
      }, message: 'API key regenerated successfully')
    rescue => e
      Rails.logger.error "Failed to regenerate API key: #{e.message}"
      render_error('Failed to regenerate API key', :internal_server_error)
    end
  end
  
  def destroy
    app_name = @current_app_profile.name
    
    begin
      @current_app_profile.destroy!
      
      render_success({
        app_name: app_name,
        deleted_at: Time.current.iso8601
      }, message: 'API key deleted successfully')
    rescue => e
      Rails.logger.error "Failed to delete API key: #{e.message}"
      render_error('Failed to delete API key', :internal_server_error)
    end
  end
end
