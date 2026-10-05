Sequel.migration do
  change do
    alter_table(:processes) do
      add_column :service_account_guid, String, size: 255
      add_column :service_account_snapshot, TrueClass, null: false, default: false
    end
  end
end
