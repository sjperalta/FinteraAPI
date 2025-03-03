class AddAddressToLots < ActiveRecord::Migration[8.0]
  def change
    add_column :lots, :address, :string
  end
end
