Sequel.migration do
  change do
    alter_table :service_bindings do
      add_column :name, String, size: 255, null: true
      add_unique_constraint [:app_guid, :name], name: :unique_service_binding_app_guid_name
    end
  end
end
