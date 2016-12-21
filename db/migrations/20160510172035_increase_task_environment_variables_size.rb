Sequel.migration do
  up do
    alter_table :tasks do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :encrypted_environment_variables, String, size: :max, null: true
      else
        set_column_type :encrypted_environment_variables, String, text: true, null: true
      end
    end
  end

  down do
    alter_table :tasks do
      set_column_type :encrypted_environment_variables, String, null: true
    end
  end
end
