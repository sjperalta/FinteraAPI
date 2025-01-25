class AddIpAndUserAgentToVersions < ActiveRecord::Migration[7.0]
  def change
    add_column :versions, :ip, :string
    add_column :versions, :user_agent, :string

     # Optional: Add indexes if you plan to query by these fields frequently
     add_index :versions, :ip
     add_index :versions, :user_agent
  end
end
