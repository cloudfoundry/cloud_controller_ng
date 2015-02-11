Sequel.migration do
  change do
    alter_table :apps_v3 do
      add_column :desired_droplet_guid, String
      add_index :desired_droplet_guid, name: :apps_desired_droplet_guid
    end
  end
end
