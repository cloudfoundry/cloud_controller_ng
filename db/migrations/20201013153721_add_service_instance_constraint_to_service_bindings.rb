Sequel.migration do
  change do
    alter_table :service_bindings do
      add_unique_constraint [:service_instance_guid, :app_guid], name: :unique_service_binding_service_instance_guid_app_guid
    end
  end
end
