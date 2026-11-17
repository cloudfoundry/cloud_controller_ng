Sequel.migration do
  change do
    alter_table(:tasks) do
      add_column :service_account_guid, String, size: 255
    end
  end
end
