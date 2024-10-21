class CreateProjects < ActiveRecord::Migration[7.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false                   # Nombre del proyecto
      t.text :description, null: false              # Descripción del proyecto
      t.string :project_type, default: "residential"        # Tipo de proyecto
      t.string :address, null: false                # Dirección del proyecto
      t.integer :lot_count, null: false             # Cantidad de lotes en el proyecto
      t.decimal :price_per_square_foot, null: false, precision: 10, scale: 2  # Precio por vara cuadrada
      t.decimal :interest_rate, null: false, precision: 5, scale: 2           # Tasa de interés
      t.string :guid, null: false, unique: true

      t.timestamps
    end
  end
end
