Sequel.migration do
  up do
    alter_table(:apps) do
      if Sequel::Model.db.database_type == :mssql
        drop_constraint(Sequel::Model.db.default_constraint_name('APPS', 'MEMORY'))
      end

      set_column_default :memory, nil
    end
  end

  down do
    alter_table(:apps) do
      if Sequel::Model.db.database_type == :mssql
        drop_constraint(Sequel::Model.db.default_constraint_name('APPS', 'MEMORY'))
      end
      set_column_default :memory, 256
    end
  end
end
