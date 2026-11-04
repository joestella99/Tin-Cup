Rails.application.routes.draw do
  root "trips#index"
  resource :session, only: [ :new, :create, :destroy ]
  resources :trips, only: [ :index, :new, :create, :show ] do
    resources :teams, only: [ :create ]
    resources :players, only: [ :create, :update ]
    resources :rounds, only: [ :create, :show ] do
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
