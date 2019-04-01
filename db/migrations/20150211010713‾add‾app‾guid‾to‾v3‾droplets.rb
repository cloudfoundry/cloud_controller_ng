Sequel.migration do
  change do
    alter_table :v3_droplets do
      add_column :app_guid, String
      add_index :app_guid
    end
  end
end
