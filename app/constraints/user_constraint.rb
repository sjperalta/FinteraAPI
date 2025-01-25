class UserConstraint
  def matches?(request)
    user = request.env['warden']&.user
    user && user.user?
  end
end
