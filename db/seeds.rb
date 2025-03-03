puts "Iniciando seeds ambiente: #{ENV['RAILS_ENV']}"

# Verifica si el usuario ya existe antes de crearlo para evitar duplicados
admin_user = User.find_or_create_by!(email: 'admin@example.com') do |user|
  user.password = 'superPassword@123'
  user.password_confirmation = 'superPassword@123'
  user.role = 'admin'
  user.full_name = 'Administrador'
  user.phone = '+50431848112'
  user.identity = '00000000000'
  user.rtn = '000000000000'
  user.confirmed_at = Time.now
end

puts "Usuario admin creado/actualizado: #{admin_user.email}"

user = User.find_or_create_by!(email: 'vendedor@example.com') do |user|
  user.password = 'Prueba123'
  user.password_confirmation = 'Prueba123'
  user.role = 'seller'
  user.full_name = 'Juan Perez'
  user.phone = '+50498586221'
  user.identity = '0506199100444'
  user.rtn = '05061991004441'
  user.confirmed_at = Time.now
end

puts "Usuario seller creado/actualizado: #{user.email}"

project = Project.find_or_create_by!(name: 'Proyecto Wameru') do |project|
  project.description = 'Proyecto Residencial En Sector Cieneguita'
  project.project_type = 'Residencial'
  project.address = 'Cieneguita, Wameru'
  project.lot_count = 100
  project.price_per_square_vara = 2500
  project.interest_rate = 5
end

puts "Projecto creado/actualizado: #{project.name}"

lot = Lot.find_or_create_by!(
  project: project,
  name: 'Lote 1',
  length: 30.0,
  width: 20.0,
  price: 30 * 20 * 2500
)

lot = Lot.find_or_create_by!(
  project: project,
  name: 'Lote 2',
  length: 10.0,
  width: 23.0,
  price: 10 * 23 * 2500
)

puts "Lote creado/actualizado: #{lot.name} with price #{lot.price}"

# Crear un contrato asociado al lote y al usuario
contract = Contract.find_or_create_by!(
  lot: lot,
  applicant_user_id: user.id,
  payment_term: 12,
  financing_type: 'direct',
  reserve_amount: 50000.00,
  down_payment: 210000.00,
  status: 'approved',
  currency: 'HNL'
)

puts "Contrato creado/actualizado: #{contract.id} with payment_term #{contract.payment_term}"

if contract.payments.exists?
  puts "Contract #{contract.id} already has payments. Skipping payment creation."
else
  # Create payments since none exist
  contract.create_payments
  puts "Payments created for Contract #{contract.id}."
end

# payment = contract.payments.first_or_initialize
# payment = payment.due_date = Time.now.ago(1.month)
# #payment.save!
