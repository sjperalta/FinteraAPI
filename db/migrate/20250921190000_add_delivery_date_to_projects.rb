class AddDeliveryDateToProjects < ActiveRecord::Migration[8.0]
  def up
    add_column :projects, :delivery_date, :date
  end

  def down
    remove_column :projects, :delivery_date
  end
end
