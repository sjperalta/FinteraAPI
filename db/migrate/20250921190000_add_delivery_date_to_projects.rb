# frozen_string_literal: true

class AddDeliveryDateToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :delivery_date, :date
  end
end
