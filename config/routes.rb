require 'sidekiq/web'

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'auth#login'
      post 'auth/refresh', to: 'auth#refresh'
      post 'auth/logout', to: 'auth#logout'
      post 'users/password', to: 'users#recover_password', as: 'recover_password'

      devise_for :users, controllers: {
        registrations: 'api/v1/users'
      }

      resources :users, only: [:index, :show, :create, :update] do
        member do
          put   :toggle_status     # Route for toggling user status
          post  :recover_password
          patch :change_password
          post  :resend_confirmation
          get   :contracts         # GET /api/v1/users/:id/contracts
          get   :payments          # GET /api/v1/users/:id/payments
          get   :summary
        end
      end

      resources :statistics, only: [:index] do
        collection do
          get :monthly_revenue
        end
      end

      resources :notifications, only: [:index, :show, :update, :destroy] do
        collection do
          post :mark_all_as_read  # optional
        end
      end

      namespace :reports do
        get :commissions_csv
        get :total_revenue_csv
        get :overdue_payments_csv
      end

      resources :contracts, only: [:index]
      resources :audits, only: [:index]
      resources :payments, only: [:index, :show] do
        member do
          post :approve
          post :upload_receipt
        end
      end
      resources :projects, only: [:index, :show, :create, :destroy] do

        member do
          post :approve      # Aprobar un proyecto
        end

        resources :lots do
          resources :contracts do
            member do
              post :approve   # Aprobar un contrato
              post :reject    # Rechazar un contrato
              post :cancel    # Cancelar un contrato
            end

            resources :payments, only: [:index, :show] do
              member do
                post :approve        # Aprobar un pago
                post :reject         # Rechazar un pago
                post :upload_receipt # Subir un recibo de pago
              end
            end
          end
        end
      end
    end
  end

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  mount Sidekiq::Web => '/sidekiq'
end
