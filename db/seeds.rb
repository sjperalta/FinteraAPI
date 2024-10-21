# Verifica si el usuario ya existe antes de crearlo para evitar duplicados
user = User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'superPassword@123'
  user.password_confirmation = 'superPassword@123'
  user.role = 'admin'
  user.confirmed_at = Time.now
end

puts "Usuario creado/actualizado: #{user.email}"

project = Project.find_or_create_by!(name: 'Proyecto Wameru') do |project|
  project.description = 'Proyecto Residencial En Sector Cieneguita'
  project.project_type = 'Residencial'
  project.address = 'Cieneguita, Wameru'
  project.lot_count = 155
  project.price_per_square_foot = 2500
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

project = Project.find_or_create_by!(name: 'Proyecto Coral') do |project|
  project.description = 'Proyecto Residencial En Sector Cieneguita'
  project.project_type = 'Residencial'
  project.address = 'Cieneguita, Wameru'
  project.lot_count = 450
  project.price_per_square_foot = 2500
  project.interest_rate = 5
end

puts "Projecto creado/actualizado: #{project.name}"

lot = Lot.find_or_create_by!(
  project: project,
  name: 'Lote 1',
  length: 10.0,
  width: 20.0
)

puts "Lote creado/actualizado: #{lot.name} with price #{lot.price}"

# Crear un contrato asociado al lote y al usuario
contract = Contract.find_or_create_by!(
  lot: lot,
  applicant_user_id: user.id,
  payment_term: 12,
  financing_type: 'direct',
  reserve_amount: 1000.0,
  down_payment: 5000.0
)

puts "Contrato creado/actualizado: #{contract.id} with payment_term #{contract.payment_term}"

# Crear un pago asociado al contrato
payment = Payment.find_or_create_by!(
  contract: contract,
  amount: 500.0,
  due_date: Date.today + 30.days,
  status: 'pending'
)

puts "Pago creado/actualizado: #{payment.id} with amount #{payment.amount}"
