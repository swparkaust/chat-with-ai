Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      # Authentication
      post 'auth/authenticate', to: 'auth#authenticate'
      get 'auth/verify', to: 'auth#verify'

      # App state
      get 'app_state', to: 'app_state#show'

      # Seasons
      resources :seasons, only: [:index, :show] do
        get 'current', on: :collection
      end

      # Conversations
      resources :conversations, only: [:index, :show] do
        get 'current', on: :collection

        # Messages
        resources :messages, only: [:index, :create] do
          post 'mark_as_read', on: :collection
        end

        # User states
        resource :user_state, only: [:update]
      end

      # Users
      resource :user, only: [:show, :update]

      # Profiles
      get 'profiles/ai', to: 'profiles#ai_profile'
      get 'profiles/me', to: 'profiles#my_profile'
      put 'profiles/me', to: 'profiles#update_my_profile'

      # Push subscriptions
      resources :subscriptions, only: [:create] do
        delete ':endpoint', action: :destroy, on: :collection
      end

      # Direct uploads (ActiveStorage)
      post 'direct_uploads', to: 'direct_uploads#create'
    end
  end

  # ActionCable
  mount ActionCable.server => '/cable'
end
