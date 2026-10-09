Sequel.migration do
  change do
    create_table :service_account_creations do
      primary_key :id, name: :service_account_creations_pkey
      String :principal_guid, size: 255, null: false
      DateTime :created_at, null: false
      index %i[principal_guid created_at], name: :service_account_creations_principal_time
    end
  end
end
