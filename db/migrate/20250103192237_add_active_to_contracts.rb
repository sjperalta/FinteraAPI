class AddActiveToContracts < ActiveRecord::Migration[7.0]
  def change
    add_column :contracts, :active, :boolean, default: false, null: false
    add_index :contracts, :active
  end
end
