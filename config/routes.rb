Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"

  Rails.application.routes.draw do
    namespace :api do
      namespace :v1 do
        post   'auth/login', to: 'auth#login'
        resources :organizations, only: [:create, :show] do
          resources :datasets, only: [:index, :create] do
            post 'upload', on: :member
          end
          resources :policies, only: [:index, :update]
        end
        resources :datasets, only: [] do
          get 'budget', on: :member
        end
        resources :queries, only: [:create, :show] do
          post 'validate', on: :collection
          post 'execute', on: :member
        end
        resources :runs, only: [:show] do
          get 'result', on: :member
          get 'attestation', on: :member
          get 'transcript', on: :member
        end
        resources :data_rooms, only: [:create] do
          post 'invite', 'attest', 'execute', on: :member
        end
        resources :audit_events, only: [:index]
      end
    end
  end

end
