# frozen_string_literal: true

# app/models/refresh_token.rb
# Model representing a refresh token for user authentication.
class RefreshToken < ApplicationRecord
  belongs_to :user
  validates :token, presence: true, uniqueness: true
  validates :expires_at, presence: true
end
