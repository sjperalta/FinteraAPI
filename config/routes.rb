Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
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
