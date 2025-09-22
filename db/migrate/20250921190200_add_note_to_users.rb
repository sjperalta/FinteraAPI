class AddNoteToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :note, :text
  end
end
