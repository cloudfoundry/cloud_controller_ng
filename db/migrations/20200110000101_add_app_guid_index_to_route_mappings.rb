Sequel.migration do
  up do
    alter_table :route_mappings do
      add_index :app_guid, name: :route_mappings_app_guid_index
    end
  end

  down do
    alter_table :route_mappings do
      drop_index :app_guid, name: :route_mappings_app_guid_index
    end
  end
end
