Sequel.migration do
  change do
    # Reservations deliberately outlive their organizations.
    create_table :service_account_prefixes do
      primary_key :id, name: :service_account_prefixes_pkey
      String :prefix, size: 63, null: false
      index :prefix, unique: true, name: :service_account_prefixes_prefix_unique
    end

    alter_table :organizations do
      add_column :service_account_prefix, String, size: 63
      # The new column is null for all existing organizations.
      add_index :service_account_prefix, unique: true, name: :organizations_service_account_prefix_unique, concurrently: false
    end
  end
end
