require 'rails_helper'

RSpec.describe Api::V1::UsersController, type: :request do
  # Crear manualmente un usuario administrador para las pruebas
  let(:admin_user) do
    User.create!(
      email: 'admin@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      full_name: 'Admin User',
      role: 'admin',
      phone: '123456789',
      confirmed_at: Time.now # Si estás usando confirmable en Devise
    )
  end

  let(:auth_headers) do
    # Autenticar el usuario usando Devise y obtener el token JWT
    token = admin_user.generate_jwt
    { 'Authorization': "Bearer #{token}" }
  end

  describe 'GET /api/v1/users' do
    it 'returns a list of users for admin' do
      # Crear algunos usuarios manualmente
      5.times do |i|
        User.create!(
          email: "user#{i}@example.com",
          password: 'password123',
          full_name: "User #{i}",
          phone: "555-000-#{i}",
          role: 'seller',
          confirmed_at: Time.now
        )
      end

      # Hacer la solicitud GET a la API
      get '/api/v1/users', headers: auth_headers

      # Esperar una respuesta exitosa
      expect(response).to have_http_status(:ok)

      # Verificar que se devuelvan usuarios en el JSON
      json = JSON.parse(response.body)
      expect(json.length).to eq(6) # Incluye también el admin_user creado
    end

    it 'returns unauthorized for non-admin users' do
      non_admin_user = User.create!(
        email: 'seller@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        full_name: 'Seller User',
        phone: '123456789',
        role: 'seller',
        confirmed_at: Time.now
      )

      token = non_admin_user.generate_jwt
      non_admin_headers = { 'Authorization': "Bearer #{token}" }

      # Hacer la solicitud GET a la API con un usuario no autorizado
      get '/api/v1/users', headers: non_admin_headers

      # Esperar una respuesta 403 Forbidden
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /api/v1/users' do
    it 'creates a new user with phone' do
      user_params = {
        user: {
          full_name: 'Test User',
          email: 'testuser@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '123456789',
          role: 'seller'
        }
      }

      # Hacer la solicitud POST a la API
      post '/api/v1/users', headers: auth_headers, params: user_params

      # Esperar una respuesta exitosa
      expect(response).to have_http_status(:created)

      # Verificar que el usuario se haya creado en la base de datos
      json = JSON.parse(response.body)
      expect(json['message']).to eq('User successfully created. Confirmation email sent.')
      created_user = User.find_by(email: 'testuser@example.com')
      expect(created_user).not_to be_nil
      expect(created_user.full_name).to eq('Test User')
      expect(created_user.phone).to eq('123456789')
    end

    it 'returns validation errors for missing params' do
      invalid_user_params = {
        user: {
          email: '', # Email vacío
          password: 'password123'
        }
      }

      # Hacer la solicitud POST con parámetros inválidos
      post '/api/v1/users', headers: auth_headers, params: invalid_user_params

      # Esperar una respuesta 422 Unprocessable Entity
      expect(response).to have_http_status(:unprocessable_entity)

      # Verificar que se devuelvan mensajes de error
      json = JSON.parse(response.body)
      expect(json['errors']).to include("Email can't be blank")
    end
  end

  describe 'GET /api/v1/users/:id' do
    it 'shows a user with phone' do
      user = User.create!(
        full_name: 'John Doe',
        email: 'john@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        phone: '987654321',
        role: 'seller',
        confirmed_at: Time.now
      )

      # Hacer la solicitud GET a la API
      get "/api/v1/users/#{user.id}", headers: auth_headers

      # Esperar una respuesta exitosa
      expect(response).to have_http_status(:ok)

      # Verificar que los datos del usuario se devuelvan correctamente
      json = JSON.parse(response.body)
      expect(json['full_name']).to eq('John Doe')
      expect(json['email']).to eq('john@example.com')
      expect(json['phone']).to eq('987654321')
    end

    it 'returns 404 if user not found' do
      # Hacer la solicitud GET con un ID que no existe
      get "/api/v1/users/99999", headers: auth_headers

      # Esperar una respuesta 404 Not Found
      expect(response).to have_http_status(:not_found)
    end
  end
end
