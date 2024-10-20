class CreateLots < ActiveRecord::Migration[7.0]
  def change
    create_table :lots do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name
      t.decimal :length
      t.decimal :width
      t.decimal :price

      t.timestamps
    end
  end
end
