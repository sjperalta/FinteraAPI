class CreateReservationRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :reservation_requests do |t|
      t.integer :lot_id
      t.integer :payment_term
      t.string :financing_type
      t.string :status
      t.integer :user_id

      t.timestamps
    end
  end
end
