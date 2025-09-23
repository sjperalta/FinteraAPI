# frozen_string_literal: true

# Migration to create the contracts table for storing contract agreements between users and lots.
class CreateContracts < ActiveRecord::Migration[7.0]
  def change
    create_table :contracts do |t|
      t.references :lot, null: false, foreign_key: true
      t.references :creator, null: true, foreign_key: { to_table: :users }
      t.references :applicant_user, null: false, foreign_key: { to_table: :users } # Usuario solicitante
      t.integer :payment_term, null: false # Plazo de pago en meses
      t.string :financing_type, null: false # Tipo de financiamiento
      t.string :status, default: 'pending' # Estado de la solicitud
      t.decimal :amount
      t.decimal :balance
      t.decimal :down_payment
      t.decimal :reserve_amount
      t.string :currency, null: false, default: 'HNL'
      t.datetime :approved_at
      t.timestamps
    end
  end
end
