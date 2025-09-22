class AddRegistrationNumberAndNoteToLots < ActiveRecord::Migration[8.0]
  def up
    add_column :lots, :registration_number, :string
    add_column :lots, :note, :text
    add_index  :lots, :registration_number unless index_exists?(:lots, :registration_number)
  end

  def down
    remove_index  :lots, :registration_number if index_exists?(:lots, :registration_number)
    remove_column :lots, :registration_number
    remove_column :lots, :note
  end
end
