class AddSellerRoleToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :seller, :boolean
  end
end
