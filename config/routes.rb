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
          resources :contracts do
            resources :payments, only: [:index, :show] do
              member do
                post 'approve'           # Aprobar un pago
                post 'reject'            # Rechazar un pago
                post 'upload_receipt'    # Subir comprobante de pago
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
