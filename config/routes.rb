Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"

  # 認証
  get "signup", to: "users#new", as: :signup
  post "signup", to: "users#create"
  resources :users, only: [:create]

  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  resource :profile, only: [:edit, :update]
  get "dev/pages", to: "dev_pages#index", as: :dev_pages

  # 一般ユーザー主要画面
  resources :meal_plans, except: [:show] do
    member do
      patch :move_dish
    end
  end

  resources :shopping_items, only: [:index, :create, :destroy] do
    member do
      patch :toggle_purchased
    end

    collection do
      delete :destroy_purchased
    end
  end

  resources :cooking_records, only: [:index, :show, :edit, :update, :destroy]
  resources :person_tags, except: [:show]

  # 管理者画面
  namespace :admin do
    root "dashboard#index"

    resources :users, only: [:index, :edit, :update, :destroy]
    resources :meal_plans, only: [:index, :show, :edit, :update, :destroy]
    resources :cooking_records, only: [:index, :show, :edit, :update, :destroy]
    resources :shopping_items, only: [:index, :show, :edit, :update, :destroy]
    resources :person_tags, only: [:index, :show, :edit, :update, :destroy]
  end

  # エラー画面
  get "403", to: "errors#forbidden", as: :forbidden
  get "404", to: "errors#not_found", as: :not_found
  get "500", to: "errors#internal_server_error", as: :internal_server_error
end
