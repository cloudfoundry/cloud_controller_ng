Sequel.migration do
  no_transaction

  up do
    options = { size: 255 }
    if database_type == :mysql
      parent = fetch("SHOW FULL COLUMNS FROM service_accounts LIKE 'guid'").first
      options[:collate] = parent[:Collation] || parent[:collation]
    end
    existing_column = schema(:apps).any? { |name, _| name == :service_account_guid }
    alter_table :apps do
      if existing_column
        set_column_type :service_account_guid, String, **options, size: 255
      else
        add_column :service_account_guid, String, **options, size: 255
      end
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
