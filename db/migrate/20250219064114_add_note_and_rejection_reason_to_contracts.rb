class AddNoteAndRejectionReasonToContracts < ActiveRecord::Migration[8.0]
  def change
    add_column :contracts, :note, :text
    add_column :contracts, :rejection_reason, :text
  end
end
