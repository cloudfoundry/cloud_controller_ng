Sequel.migration do
  up do
    add_column :route_mappings, :app_port, Integer, default: 8080

    alter_table :route_mappings do
      drop_constraint(:route_mappings_app_guid_route_guid_process_type_key)
      add_unique_constraint [:app_guid, :route_guid, :process_type, :app_port], name: :route_mappings_app_guid_route_guid_process_type_app_port_key
    end
  end

  down do
    alter_table :route_mappings do
      drop_constraint(:route_mappings_app_guid_route_guid_process_type_app_port_key, type: :unique)
      add_unique_constraint [:app_guid, :route_guid, :process_type], name: :route_mappings_app_guid_route_guid_process_type_key
    end

    drop_column :route_mappings, :app_port
  end
end
