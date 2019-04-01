Sequel.migration do
  change do
    alter_table :service_brokers do
      add_column :auth_username, String
      rename_column :token, :auth_password
    end
  end
end
