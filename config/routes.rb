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
  get "settings", to: "settings#show", as: :settings
  get "dev/pages", to: "dev_pages#index", as: :dev_pages

  # 一般ユーザー主要画面
  resources :meal_plans, except: [:show] do
    member do
      patch :move_dish
    end
  end

  resources :shopping_items, only: [:index, :create, :update, :destroy] do
    member do
      patch :toggle_purchased
    end

    collection do
      patch :reorder
      delete :destroy_purchased
    end
  end

  resources :cooking_records, only: [:index, :show, :edit, :update, :destroy, :create]
  resources :person_tags, except: [:show]

  # 管理者画面
  namespace :admin do
    root "dashboard#index"

    get "signup", to: "registrations#new", as: :signup
    post "signup", to: "registrations#create"

    resources :users, only: [:index, :show, :destroy] do
      member do
        get :meal_plans
        get :shopping_items
        get :cooking_records
      end
    end
    resources :meal_plans, only: [:index, :destroy]
    resources :cooking_records, only: [:index, :destroy]
    resources :shopping_items, only: [:index, :destroy]
    resources :person_tags, only: [:index, :destroy]
  end

  # エラー画面
  get "403", to: "errors#forbidden", as: :forbidden
  get "404", to: "errors#not_found", as: :not_found
  get "500", to: "errors#internal_server_error", as: :internal_server_error
end
