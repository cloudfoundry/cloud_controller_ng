Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      alter_table :services do
        add_column :sso_client_id, String, unique: true, unique_constraint_name: 'uq_services_sso_client_id'
      end
    else
      alter_table :services do
        add_column :sso_client_id, String, unique: true
      end
    end
  end
end
