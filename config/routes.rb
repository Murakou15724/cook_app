Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  get "signup", to: "users#new", as: :signup
  post "signup", to: "users#create"
  resources :users, only: [:create]

  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  resource :profile, only: [:edit, :update]
end
