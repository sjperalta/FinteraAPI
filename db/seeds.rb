# Verifica si el usuario ya existe antes de crearlo para evitar duplicados
user = User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'superPassword@123'
  user.password_confirmation = 'superPassword@123'
  user.admin = true
  user.seller = false
  user.confirmed_at = Time.now
end

puts "Usuario creado: #{user.email}"
