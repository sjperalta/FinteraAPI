class CreateReservations < ActiveRecord::Migration[7.0]
  def change
    create_table :reservations do |t|
      t.references :lot, null: false, foreign_key: true
      t.references :creator, null: true, foreign_key: { to_table: :users }
      t.references :applicant_user, null: false, foreign_key: { to_table: :users }  # Usuario solicitante
      t.integer :payment_term, null: false  # Plazo de pago en meses
      t.string :financing_type, null: false  # Tipo de financiamiento
      t.string :status, default: "pending"  # Estado de la solicitud

      t.timestamps
    end
  end
end
