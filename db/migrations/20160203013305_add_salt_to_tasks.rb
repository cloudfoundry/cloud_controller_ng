Sequel.migration do
  change do
    alter_table :tasks do
      if Sequel::Model.db.database_type == :mssql
        rename_column :environment_variables, 'ENCRYPTED_ENVIRONMENT_VARIABLES'
      else
        rename_column :environment_variables, :encrypted_environment_variables
      end
      add_column :salt, String
    end
  end
end
