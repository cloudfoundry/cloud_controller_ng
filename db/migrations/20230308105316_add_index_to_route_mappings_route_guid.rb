Sequel.migration do
  change do
    alter_table :route_mappings do
      add_index :route_guid, name: :route_mappings_route_guid_index
    end
  end
end
