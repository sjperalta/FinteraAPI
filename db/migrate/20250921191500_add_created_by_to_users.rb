class AddCreatedByToUsers < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:users, :created_by)
      add_column :users, :created_by, :bigint
    end

    unless foreign_key_exists?(:users, column: :created_by)
      add_foreign_key :users, :users, column: :created_by
    end

    unless index_exists?(:users, :created_by)
      add_index :users, :created_by
    end
  end
end
