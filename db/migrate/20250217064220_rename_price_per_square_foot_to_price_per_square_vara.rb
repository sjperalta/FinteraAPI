# frozen_string_literal: true

class RenamePricePerSquareFootToPricePerSquareVara < ActiveRecord::Migration[8.0]
  def change
    rename_column :projects, :price_per_square_foot, :price_per_square_vara
  end
end
