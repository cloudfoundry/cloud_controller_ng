Sequel.migration do
  no_transaction

  up do
    alter_table :apps do
      add_column :service_account_guid, String, size: 255
      add_foreign_key [:service_account_guid], :service_accounts, key: :guid, name: :fk_apps_service_account_guid
    end
    VCAP::Migration.with_concurrent_timeout(self) do
      add_index :apps, :service_account_guid, name: :apps_service_account_guid_index, concurrently: database_type == :postgres
    end
  end

  down do
    VCAP::Migration.with_concurrent_timeout(self) do
      drop_index :apps, :service_account_guid, name: :apps_service_account_guid_index, concurrently: database_type == :postgres
    end
    alter_table :apps do
      drop_foreign_key [:service_account_guid], name: :fk_apps_service_account_guid
      drop_column :service_account_guid
    end
  end
end
