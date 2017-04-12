Sequel.migration do
  change do
    alter_table :apps_v3 do
      if Sequel::Model.db.database_type == :mssql
        add_column :encrypted_environment_variables, String, size: :max
      else
        add_column :encrypted_environment_variables, String, text: true
      end
      add_column :salt, String
    end
  end
end
