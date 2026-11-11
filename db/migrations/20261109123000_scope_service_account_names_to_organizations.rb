Sequel.migration do
  up do
    organization_id_type = schema(:organizations).to_h.fetch(:id).fetch(:db_type)
    alter_table :service_accounts do
      drop_foreign_key [:name], name: :fk_service_accounts_name
      drop_index :name, name: :service_accounts_name_unique, concurrently: false
      add_column :identity_prefix, String, size: 63
    end
    alter_table :service_account_names do
      add_column :organization_id, organization_id_type
      add_column :deleted_at, DateTime
      drop_index :name, name: :service_account_names_name_unique, concurrently: false
      add_index %i[organization_id name], unique: true, name: :service_account_names_org_name_unique, concurrently: false
    end
    from(:service_accounts).each do |account|
      from(:service_account_names).where(name: account[:name]).update(organization_id: account[:organization_id])
    end
    # Existing unqualified accounts and orphan historical reservations are retained.
    # Do not infer a deleted org or historical deletion time from absent evidence.
    alter_table :service_accounts do
      add_index %i[organization_id name], unique: true, name: :service_accounts_org_name_unique, concurrently: false
    end
  end

  down do
    raise Sequel::Error.new('Org-local identities cannot be downgraded to the global account namespace') if from(:service_accounts).any?

    duplicate_names = from(:service_account_names).group(:name).having { count.function.* > 1 }.any?
    raise Sequel::Error.new('Org-local reservations cannot be collapsed into a global namespace') if duplicate_names

    # InnoDB may discard its original FK index when the composite index is added.
    # Restore a supporting index before removing the composite one on rollback.
    if database_type == :mysql && indexes(:service_accounts).values.none? { |index| index[:columns] == [:organization_id] }
      alter_table(:service_accounts) { add_index :organization_id, name: :fk_service_accounts_organization, concurrently: false }
    end

    alter_table :service_accounts do
      drop_index %i[organization_id name], name: :service_accounts_org_name_unique, concurrently: false
      drop_column :identity_prefix
      add_index :name, unique: true, name: :service_accounts_name_unique, concurrently: false
    end
    alter_table :service_account_names do
      drop_index %i[organization_id name], name: :service_account_names_org_name_unique, concurrently: false
      drop_column :organization_id
      drop_column :deleted_at
      add_index :name, unique: true, name: :service_account_names_name_unique, concurrently: false
    end
    alter_table(:service_accounts) { add_foreign_key [:name], :service_account_names, key: :name, name: :fk_service_accounts_name }
  end
end
