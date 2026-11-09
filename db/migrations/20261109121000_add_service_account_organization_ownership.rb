Sequel.migration do
  up do
    organization_id_type = schema(:organizations).to_h.fetch(:id).fetch(:db_type)
    alter_table :service_accounts do
      add_column :organization_id, organization_id_type
      add_foreign_key [:organization_id], :organizations, name: :fk_service_accounts_organization
    end

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

    # Preserve UUIDs, names, authentication state and launch references. The
    # original space is retained for old readers until the entitlement cutover.
    from(:service_accounts).each do |account|
      organization_id = from(:spaces).where(guid: account[:space_guid]).get(:organization_id)
      from(:service_accounts).where(id: account[:id]).update(organization_id: organization_id)
      from(:service_account_space_entitlements).insert(service_account_guid: account[:guid], space_guid: account[:space_guid])
    end
    alter_table(:service_accounts) { set_column_not_null :organization_id }
  end

  down do
    drop_table :service_account_space_entitlements
    alter_table :service_accounts do
      drop_foreign_key [:organization_id], name: :fk_service_accounts_organization
      drop_column :organization_id
    end
  end
end
