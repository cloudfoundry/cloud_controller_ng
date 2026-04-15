Sequel.migration do
  up do
    unless table_exists?(:route_access_rule_annotations)
      create_table :route_access_rule_annotations do
        primary_key :id
        String :guid, null: false, size: 255
        String :resource_guid, null: false, size: 255
        String :key_prefix, size: 253
        String :key, null: false, size: 1000
        String :value, size: 5000
        DateTime :created_at, null: false
        DateTime :updated_at

        index :guid, unique: true, name: :route_access_rule_annotations_guid_index
        index :resource_guid, name: :route_access_rule_annotations_resource_guid_index
        index %i[resource_guid key], unique: true, name: :route_access_rule_annotations_key_index
        foreign_key [:resource_guid], :route_access_rules, key: :guid, on_delete: :cascade, name: :fk_route_access_rule_annotations_resource_guid
      end
    end
  end

  down do
    drop_table(:route_access_rule_annotations) if table_exists?(:route_access_rule_annotations)
  end
end
