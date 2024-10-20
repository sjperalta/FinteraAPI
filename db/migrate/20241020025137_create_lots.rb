class CreateLots < ActiveRecord::Migration[7.0]
  def change
    create_table :lots do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false  # Nombre del lote
      t.decimal :length, null: false, precision: 10, scale: 2  # Longitud del lote
      t.decimal :width, null: false, precision: 10, scale: 2  # Ancho del lote
      t.decimal :price, null: false, precision: 15, scale: 2  # Precio del lote

      t.timestamps
    end
  end
end
