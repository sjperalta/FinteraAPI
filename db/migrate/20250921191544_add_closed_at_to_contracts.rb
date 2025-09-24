class AddClosedAtToContracts < ActiveRecord::Migration[8.0]
  def change
    add_column :contracts, :closed_at, :datetime unless column_exists?(:contracts, :closed_at)
    add_index :contracts, :status unless index_exists?(:contracts, :status)
  end
end
