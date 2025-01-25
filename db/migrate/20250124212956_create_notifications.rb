# db/migrate/XXXXXXXXXXXXXX_create_notifications.rb
class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :message, null: false
      t.string :notification_type
      t.datetime :read_at

      t.timestamps
    end

     # Additional indexes
     add_index :notifications, :read_at
     add_index :notifications, :notification_type
     add_index :notifications, :created_at
  end
end
