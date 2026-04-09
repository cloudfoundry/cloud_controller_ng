Sequel.migration do
  up do
    unless table_exists?(:route_access_rules)
      create_table :route_access_rules do
        String :guid, size: 255, null: false
        primary_key :id
        String :name, size: 255, null: false
        String :selector, size: 255, null: false
        Integer :route_id, null: false
        DateTime :created_at, null: false
        DateTime :updated_at, null: false

        index :guid, unique: true, name: :route_access_rules_guid_index
        index %i[route_id name], unique: true, name: :route_access_rules_route_id_name_index
        index %i[route_id selector], unique: true, name: :route_access_rules_route_id_selector_index
        foreign_key [:route_id], :routes, on_delete: :cascade, name: :fk_route_access_rules_route_id
      end
    end
  end

  down do
    drop_table(:route_access_rules) if table_exists?(:route_access_rules)
  end
end
