Sequel.migration do
  no_transaction

  up do
    options = { size: 255 }
    if database_type == :mysql
      parent = fetch("SHOW FULL COLUMNS FROM service_accounts LIKE 'guid'").first
      options[:collate] = parent[:Collation] || parent[:collation]
    end
    existing_column = schema(:apps).any? { |name, _| name == :service_account_guid }
    existing_foreign_key = foreign_key_list(:apps).any? { |key| key[:name] == :fk_apps_service_account_guid }
    alter_table :apps do
      if existing_column && !existing_foreign_key
        set_column_type :service_account_guid, String, **options, size: 255
      elsif !existing_column
        add_column :service_account_guid, String, **options, size: 255
      end
      add_foreign_key [:service_account_guid], :service_accounts, key: :guid, name: :fk_apps_service_account_guid unless existing_foreign_key
    end
    VCAP::Migration.with_concurrent_timeout(self) do
      if database_type == :postgres
        index_valid = fetch("SELECT indisvalid FROM pg_index WHERE indexrelid = to_regclass('apps_service_account_guid_index')").get(:indisvalid)
        drop_index :apps, :service_account_guid, name: :apps_service_account_guid_index, concurrently: true if index_valid == false
        add_index :apps, :service_account_guid, name: :apps_service_account_guid_index, concurrently: true unless index_valid
      elsif !indexes(:apps).key?(:apps_service_account_guid_index)
        add_index :apps, :service_account_guid, name: :apps_service_account_guid_index, concurrently: false
      end
    end
  end

  down do
    alter_table(:apps) { drop_foreign_key [:service_account_guid], name: :fk_apps_service_account_guid }
    VCAP::Migration.with_concurrent_timeout(self) do
      drop_index :apps, :service_account_guid, name: :apps_service_account_guid_index, concurrently: database_type == :postgres
    end
    alter_table :apps do
      drop_column :service_account_guid
    end
  end
end
