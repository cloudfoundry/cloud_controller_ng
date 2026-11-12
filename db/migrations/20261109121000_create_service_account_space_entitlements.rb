Sequel.migration do
  up do
    account_guid_options = {}
    space_guid_options = {}
    if database_type == :mysql
      account_column = fetch("SHOW FULL COLUMNS FROM service_accounts LIKE 'guid'").first
      space_column = fetch("SHOW FULL COLUMNS FROM spaces LIKE 'guid'").first
      account_guid_options[:collate] = account_column[:Collation] || account_column[:collation]
      space_guid_options[:collate] = space_column[:Collation] || space_column[:collation]
    end

    create_table :service_account_space_entitlements do
      String :service_account_guid, **account_guid_options, size: 255, null: false
      String :space_guid, **space_guid_options, size: 255, null: false
      primary_key %i[service_account_guid space_guid], name: :service_account_space_entitlements_pkey
      foreign_key [:service_account_guid], :service_accounts, key: :guid, name: :fk_sa_entitlements_account, on_delete: :cascade
      foreign_key [:space_guid], :spaces, key: :guid, name: :fk_sa_entitlements_space, on_delete: :cascade
    end
  end

  down do
    drop_table :service_account_space_entitlements
  end
end
