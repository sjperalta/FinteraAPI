Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'auth#login'
      resources :users, only: [:create] do
        collection do
          post 'password', to: 'users#recover_password'
        end
      end
      resources :projects do
        resources :lots do
          resources :reservations, only: [:create, :index, :show, :update, :destroy] do
            member do
              post 'approve'
              post 'reject'
              post 'cancel'
            end
          end
        end
      end
    end
  end

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
end
