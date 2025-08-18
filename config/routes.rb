Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Query analysis endpoints
      post 'analyze', to: 'analysis#analyze'
      post 'analyze_ci', to: 'analysis#analyze_ci'

      # API key management endpoints
      post 'api_keys', to: 'api_keys#create'
      get 'api_keys/current', to: 'api_keys#show'
      post 'api_keys/regenerate', to: 'api_keys#regenerate'
      delete 'api_keys/current', to: 'api_keys#destroy'

      # Health check endpoint
      get 'health', to: 'health#show'
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
