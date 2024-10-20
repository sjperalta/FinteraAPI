# Verifica si el usuario ya existe antes de crearlo para evitar duplicados
user = User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'superPassword@123'
  user.password_confirmation = 'superPassword@123'
  user.role = 'admin'
  user.confirmed_at = Time.now
end

puts "Usuario creado/actualizado: #{user.email}"


project = Project.find_or_create_by!(name: 'Proyecto Ejemplo') do |project|
  project.description = 'Descripción del proyecto'
  project.address = 'Dirección'
  project.lot_count = 1
  project.price_per_square_foot = 100
  project.interest_rate = 5
end

puts "Projecto creado/actualizado: #{project.name}"

lot = Lot.find_or_create_by!(
  project: project,
  name: 'Lote 1',
  length: 30.0,
  width: 20.0
)

puts "Lote creado/actualizado: #{lot.name} with price #{lot.price}"
