# frozen_string_literal: true

# db/migrate/20250124000000_add_commission_rate_to_projects.rb

# Migration to add commission_rate column to projects table for tracking commission percentages.
class AddCommissionRateToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :commission_rate, :decimal, precision: 5, scale: 2, default: 0.0, null: false
  end
end
