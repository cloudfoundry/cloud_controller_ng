Sequel.migration do
  change do
    create_table :service_account_names do
      primary_key :id, name: :service_account_names_pkey
      String :name, size: 63, null: false
      index :name, unique: true, name: :service_account_names_name_unique
    end

    create_table :service_accounts do
      VCAP::Migration.common(self)
      String :name, size: 63, null: false
      foreign_key [:name], :service_account_names, key: :name, name: :fk_service_accounts_name
      index :name, unique: true, name: :service_accounts_name_unique
      String :space_guid, size: 255, null: false
      foreign_key [:space_guid], :spaces, key: :guid, name: :fk_service_accounts_space
      TrueClass :enabled, null: false, default: true
      String :status, size: 32, null: false, default: 'reserved'
    end
  end
end
