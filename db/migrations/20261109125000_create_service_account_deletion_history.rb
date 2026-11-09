Sequel.migration do
  change do
    create_table :service_account_name_deletions do
      primary_key :id, name: :service_account_name_deletions_pkey
      String :account_guid, size: 255, null: false
      String :organization_guid, size: 255, null: false
      String :name, size: 63, null: false
      String :identity_prefix, size: 63
      DateTime :deleted_at, null: false
      index :account_guid, unique: true, name: :service_account_deletions_account_unique
      index :deleted_at, name: :service_account_deletions_time_index
    end
  end
end
