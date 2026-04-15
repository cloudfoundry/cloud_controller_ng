Sequel.migration do
  up do
    alter_table :route_access_rules do
      drop_index %i[route_id name], name: :route_access_rules_route_id_name_index
      drop_column :name
    end
  end

  down do
    alter_table :route_access_rules do
      add_column :name, String, size: 255
      add_index %i[route_id name], unique: true, name: :route_access_rules_route_id_name_index
    end
  end
end
