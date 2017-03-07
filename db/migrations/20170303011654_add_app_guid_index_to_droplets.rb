Sequel.migration do
  change do
    alter_table :droplets do
      add_index :app_guid, name: :droplet_app_guid_index
    end
  end
end
