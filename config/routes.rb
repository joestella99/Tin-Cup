Rails.application.routes.draw do
  root "trips#index"
  resource :account, only: [ :show ]
  resource :recovery_code, only: [ :create ]
  resource :registration, only: [ :new, :create ]
  resource :recovery, only: [ :new, :create ]
  get "/watch/:token", to: "spectators#show", as: :watch
  get "/watch/:token/live", to: "spectators#live", as: :watch_live
  get "/join/:token", to: "joins#show", as: :join
  post "/join/:token", to: "joins#create"
  resource :session, only: [ :new, :create, :destroy ]
  resources :trips, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    get :delete_confirmation, on: :member
    get "clubhouse", to: "clubhouses#show", as: :clubhouse
    get "clubhouse/live", to: "clubhouses#live", as: :live_clubhouse
    resource :claim, only: [ :create ]
    resources :invitations, only: [ :create, :destroy ]
    resources :spectator_passes, only: [ :create, :destroy ]
    resources :memberships, only: [ :destroy ]
    resources :golf_courses, only: [ :index, :show, :create ] do
      post :refresh, on: :member
    end
    resources :teams, only: [ :create, :destroy ]
    resources :players, only: [ :create, :update, :destroy ]
    resources :rounds, only: [ :create, :show, :edit, :update, :destroy ] do
      get :cart, on: :member
      resource :scorecard, only: [ :update ]
      resource :scorecard_import, only: [ :new, :create ]
      resource :course_card, only: [ :edit, :update ]
      resources :matches, only: [ :create, :destroy ]
      resource :skins_game, only: [ :show ]
      resource :pairing_suggestions, only: [ :show, :create ]
      resources :holes, only: [] do
        resource :hole_scores, only: [ :update ]
      end
    end
  end
  get "up" => "rails/health#show", as: :rails_health_check
end
