Sequel.migration do
  up do
    unless table_exists?(:route_access_rules)
      create_table :route_access_rules do
        primary_key :id, name: :id
        String :guid, size: 255, null: false
        String :selector, size: 255, null: false
        Integer :route_id, null: false
        DateTime :created_at, null: false
        DateTime :updated_at, null: false

        index :guid, unique: true, name: :route_access_rules_guid_index
        index %i[route_id selector], unique: true, name: :route_access_rules_route_id_selector_index
        foreign_key [:route_id], :routes, on_delete: :cascade, name: :fk_route_access_rules_route_id
      end
    end

    unless table_exists?(:route_access_rule_labels)
      create_table :route_access_rule_labels do
        primary_key :id, name: :id
        String :guid, null: false, size: 255
        String :resource_guid, null: false, size: 255
        String :key_prefix, size: 253
        String :key_name, null: false, size: 63
        String :value, null: false, size: 63
        DateTime :created_at, null: false
        DateTime :updated_at

        index :guid, unique: true, name: :route_access_rule_labels_guid_index
        index :resource_guid, name: :route_access_rule_labels_resource_guid_index
        index %i[resource_guid key_prefix key_name], unique: true, name: :route_access_rule_labels_compound_index
        foreign_key [:resource_guid], :route_access_rules, key: :guid, on_delete: :cascade, name: :fk_route_access_rule_labels_resource_guid
      end
    end

    unless table_exists?(:route_access_rule_annotations)
      create_table :route_access_rule_annotations do
        primary_key :id, name: :id
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
    %i[route_access_rule_annotations route_access_rule_labels route_access_rules].each { |t| drop_table(t) if table_exists?(t) }
  end
end
