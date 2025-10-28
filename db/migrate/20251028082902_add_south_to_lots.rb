class AddSouthToLots < ActiveRecord::Migration[8.0]
  def change
    add_column :lots, :south, :string
  end
end
