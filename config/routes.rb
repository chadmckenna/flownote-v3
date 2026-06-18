Rails.application.routes.draw do
  resources :folders, only: [ :show, :new, :create, :edit, :update, :destroy ] do
    resources :notes, except: [ :index ]
  end
  use_doorkeeper do
    skip_controllers :applications, :authorized_applications
  end
  get "search", to: "search#index"
  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  namespace :api do
    namespace :v1 do
      resource :me, only: :show, controller: "me"
      resources :folders, only: %i[index show create destroy] do
        resources :notes, only: %i[index], shallow: true
      end
      resources :notes, only: %i[show create update destroy]
    end
  end

  root "folders#index"
end
