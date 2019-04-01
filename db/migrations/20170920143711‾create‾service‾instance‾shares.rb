Sequel.migration do
  change do
    create_table :service_instance_shares do
      String :service_instance_guid, null: false, size: 255
      String :target_space_guid, null: false, size: 255

      foreign_key [:service_instance_guid], :service_instances, key: :guid, name: :fk_service_instance_guid, on_delete: :cascade
      foreign_key [:target_space_guid], :spaces, key: :guid, name: :fk_target_space_guid, on_delete: :cascade
      primary_key [:service_instance_guid, :target_space_guid], name: :service_instance_target_space_pk
    end
  end
end
