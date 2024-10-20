Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'auth#login'
      resources :users, only: [:create] do
        collection do
          post 'password', to: 'users#recover_password'
        end
      end
      resources :projects
      resources :reservation_requests, only: [:index, :create] do
        member do
          patch 'approve'
          patch 'reject'
          delete 'cancel'
        end
      end
    end
  end
end
