class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.references :contracts, null: false, foreign_key: true
      t.decimal :amount
      t.date :due_date
      t.date :payment_date
      t.string :status

      t.timestamps
    end
  end
end
