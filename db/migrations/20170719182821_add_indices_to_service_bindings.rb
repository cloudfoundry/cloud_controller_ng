Sequel.migration do
  change do
    alter_table :service_bindings do
      add_index :app_guid, name: :service_bindings_app_guid_index
      add_index :service_instance_guid, name: :service_bindings_service_instance_guid_index
    end
  end
end
