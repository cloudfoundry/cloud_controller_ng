Sequel.migration do
  change do
    alter_table(:service_bindings) { add_column :service_account_guid, String, size: 255 }
  end
end
