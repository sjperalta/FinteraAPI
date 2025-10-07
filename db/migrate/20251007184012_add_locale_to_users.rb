# frozen_string_literal: true

# db/migrate/20251007184012_add_locale_to_users.rb
# Migration to add locale column to users table
class AddLocaleToUsers < ActiveRecord::Migration[8.0]
  TABLE = :users
  COLUMN = :locale
  TYPE = :string

  def up
    return nil unless table_exists?(TABLE)

    return if column_exists?(TABLE, COLUMN)

    add_column(TABLE, COLUMN, TYPE, default: 'es', null: false)
    add_index(TABLE, COLUMN)
  end

  def down
    return nil unless table_exists?(TABLE)
    return nil unless column_exists?(TABLE, COLUMN)

    remove_column(TABLE, COLUMN)
  end
end
