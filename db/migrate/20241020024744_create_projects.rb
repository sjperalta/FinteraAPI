class CreateProjects < ActiveRecord::Migration[7.0]
  def change
    create_table :projects do |t|
      t.string :name
      t.text :description
      t.string :address
      t.integer :lot_count
      t.decimal :price_per_square_foot
      t.decimal :interest_rate
      t.string :guid

      t.timestamps
    end
  end
end
