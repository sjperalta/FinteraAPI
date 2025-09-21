class AddOverridePriceToLots < ActiveRecord::Migration[7.1]
  def up
    add_column :lots, :override_price, :decimal, precision: 15, scale: 2
  end

  def down
    remove_column :lots, :override_price
  end
end
