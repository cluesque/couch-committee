Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session, only: %i[ new destroy ]
  # google_sign_in's proceed_to target: it redirects here (a GET) once Google has answered.
  get "session/google", to: "sessions#create", as: :google_session

  resources :groups, only: %i[ index show new create ] do
    scope module: :groups do
      resources :memberships, only: %i[ create destroy ]
      resources :lists, only: %i[ show new create edit update ] do
        resource :history, only: :show, module: :lists
        resources :list_entries, only: %i[ show new create ], module: :lists do
          patch :reorder, on: :collection
          get :seasons, on: :collection
          scope module: :list_entries do
            resources :viewings, only: %i[ new create ]
            resource :cancellation, only: %i[ new create ]
          end
        end
      end
    end
  end

  resources :titles, only: %i[ index show new create ]

  root "groups#index"
end
