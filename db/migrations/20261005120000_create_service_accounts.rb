Sequel.migration do
  up do
    organization_id_type = schema(:organizations).to_h.fetch(:id).fetch(:db_type)
    create_table :service_account_names do
      primary_key :id, name: :service_account_names_pkey
      String :name, size: 63, null: false
      column :organization_id, organization_id_type, null: false
      DateTime :deleted_at
      index %i[organization_id name], unique: true, name: :service_account_names_org_name_unique
    end

    create_table :service_accounts do
      VCAP::Migration.common(self)
      String :name, size: 63, null: false
      column :organization_id, organization_id_type, null: false
      foreign_key [:organization_id], :organizations, name: :fk_service_accounts_organization
      String :identity_prefix, size: 63, null: false
      index %i[organization_id name], unique: true, name: :service_accounts_org_name_unique
      TrueClass :enabled, null: false, default: true
      String :status, size: 32, null: false, default: 'reserved'
    end
  end

  down do
    drop_table :service_accounts
    drop_table :service_account_names
  end
end
