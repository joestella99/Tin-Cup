Rails.application.routes.draw do
  root "trips#index"
  resource :account, only: [ :show ]
  resource :recovery_code, only: [ :create ]
  resource :registration, only: [ :new, :create ]
  resource :recovery, only: [ :new, :create ]
  get "/join/:token", to: "joins#show", as: :join
  post "/join/:token", to: "joins#create"
  resource :session, only: [ :new, :create, :destroy ]
  resources :trips, only: [ :index, :new, :create, :show, :edit, :update ] do
    resource :claim, only: [ :create ]
    resources :invitations, only: [ :create, :destroy ]
    resources :memberships, only: [ :destroy ]
    resources :teams, only: [ :create ]
    resources :players, only: [ :create, :update ]
    resources :rounds, only: [ :create, :show, :edit, :update ] do
      resource :scorecard, only: [ :update ]
      resource :course_card, only: [ :edit, :update ]
      resources :matches, only: [ :create, :destroy ]
      resources :holes, only: [] do
        resource :hole_scores, only: [ :update ]
      end
    end
  end
  get "up" => "rails/health#show", as: :rails_health_check
end
