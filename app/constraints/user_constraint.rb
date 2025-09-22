# frozen_string_literal: true

class UserConstraint
  def matches?(request)
    user = request.env['warden']&.user
    user&.user?
  end
end
