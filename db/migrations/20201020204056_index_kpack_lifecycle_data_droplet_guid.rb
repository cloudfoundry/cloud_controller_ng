Sequel.migration do
  up do
    alter_table :kpack_lifecycle_data do
      add_index :droplet_guid, name: :kpack_lifecycle_droplet_guid_index
    end
  end

  down do
    alter_table :kpack_lifecycle_data do
      drop_index :droplet_guid, name: :kpack_lifecycle_droplet_guid_index
    end
  end
end
