class AddMeasurementUnitToProjectsAndLots < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :measurement_unit, :string, null: false, default: 'm2'
    add_column :lots, :measurement_unit, :string

    reversible do |dir|
      dir.up do
        rename_column :projects, :price_per_square_vara, :price_per_square_unit
        execute <<~SQL
          UPDATE lots SET measurement_unit = 'm2' WHERE measurement_unit IS NULL;
        SQL
      end
      dir.down do
        rename_column :projects, :price_per_square_unit, :price_per_square_vara
      end
    end
  end
end
