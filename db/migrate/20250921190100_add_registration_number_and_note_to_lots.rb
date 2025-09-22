class AddRegistrationNumberAndNoteToLots < ActiveRecord::Migration[8.0]
  def change
    add_column :lots, :registration_number, :string
    add_column :lots, :note, :text
    add_index  :lots, :registration_number unless index_exists?(:lots, :registration_number)
  end
end
