class AddNoteToUsers < ActiveRecord::Migration[7.0]
  def up
    add_column :users, :note, :text
  end

  def down
    remove_column :users, :note
  end
end