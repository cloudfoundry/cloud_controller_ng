Sequel.migration do
  up do
    unless table_exists?(:route_policies)
      create_table :route_policies do
        primary_key :id, name: :id
        String :guid, size: 255, null: false
        String :source, size: 255, null: false
        Integer :route_id, null: false
        DateTime :created_at, null: false
        DateTime :updated_at, null: false

        index :guid, unique: true, name: :route_policies_guid_index
        index %i[route_id source], unique: true, name: :route_policies_route_id_source_index
        foreign_key [:route_id], :routes, on_delete: :cascade, name: :fk_route_policies_route_id
      end
    end

    unless table_exists?(:route_policy_labels)
      create_table :route_policy_labels do
        primary_key :id, name: :id
        String :guid, null: false, size: 255
        String :resource_guid, null: false, size: 255
        String :key_prefix, null: false, default: '', size: 253
        String :key_name, null: false, size: 63
        String :value, null: false, size: 63
        DateTime :created_at, null: false
        DateTime :updated_at

        index :guid, unique: true, name: :route_policy_labels_guid_index
        index :resource_guid, name: :route_policy_labels_resource_guid_index
        index %i[resource_guid key_prefix key_name], unique: true, name: :route_policy_labels_compound_index
        foreign_key [:resource_guid], :route_policies, key: :guid, on_delete: :cascade, name: :fk_route_policy_labels_resource_guid
      end
    end

    unless table_exists?(:route_policy_annotations)
      create_table :route_policy_annotations do
        primary_key :id, name: :id
        String :guid, null: false, size: 255
        String :resource_guid, null: false, size: 255
        String :key_prefix, null: false, default: '', size: 253
        String :key_name, null: false, size: 63
        String :value, size: 5000
        DateTime :created_at, null: false
        DateTime :updated_at

        index :guid, unique: true, name: :route_policy_annotations_guid_index
        index :resource_guid, name: :route_policy_annotations_resource_guid_index
        index %i[resource_guid key_prefix key_name], unique: true, name: :route_policy_annotations_key_index
        foreign_key [:resource_guid], :route_policies, key: :guid, on_delete: :cascade, name: :fk_route_policy_annotations_resource_guid
      end
    end
  end

  down do
    %i[route_policy_annotations route_policy_labels route_policies].each { |t| drop_table(t) if table_exists?(t) }
  end
end
