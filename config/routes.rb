Rails.application.routes.draw do
  root "trips#index"
  resource :session, only: [ :new, :create, :destroy ]
  resources :trips, only: [ :index, :new, :create, :show ] do
    resources :players, only: [ :create ]
    resources :rounds, only: [ :create, :show ] do
      resource :scorecard, only: [ :update ]
    end
  end
  get "up" => "rails/health#show", as: :rails_health_check
end
