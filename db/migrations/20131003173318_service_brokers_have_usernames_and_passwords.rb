Sequel.migration do
  change do
    alter_table :service_brokers do
      add_column :auth_username, String
      if Sequel::Model.db.database_type == :mssql
        rename_column :token, 'AUTH_PASSWORD'
      else
        rename_column :token, :auth_password
      end
    end
  end
end
