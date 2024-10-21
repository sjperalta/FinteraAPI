class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.references :contract, null: false, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.date :due_date, null: false
      t.date :payment_date
      t.string :status, null: false, default: 'pending'
      t.datetime :approved_at

      t.timestamps
    end
  end
end
