Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      post 'auth/login', to: 'auth#login'
      post 'auth/refresh', to: 'auth#refresh'
      post 'auth/logout', to: 'auth#logout'

      devise_for :users, controllers: {
        registrations: 'api/v1/users'
      }
      resources :users, only: [:index, :show, :create, :update] do
        member do
          put :toggle_status # Route for toggling user status
          post :resend_confirmation
        end
      end
      post 'users/password', to: 'users#recover_password', as: 'recover_password'

      get 'search/contracts', to: 'search#contracts'

      resources :projects, only: [:index, :show, :create, :approve, :destroy] do

        member do
          post 'approve'   # Aprobar un proyecto
        end

        resources :lots do
          resources :contracts do
            member do
              post 'approve'   # Aprobar un contrato
              post 'reject'    # Rechazar un contrato
              post 'cancel'    # Cancelar un contrato
            end

            resources :payments, only: [:index, :show] do
              member do
                post 'approve'        # Aprobar un pago
                post 'reject'         # Rechazar un pago
                post 'upload_receipt' # Subir un recibo de pago
              end
            end
          end
        end
      end
    end
  end

  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
end
