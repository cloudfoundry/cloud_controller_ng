Sequel.migration do
  up do
    alter_table :apps do
      if Sequel::Model.db.database_type == :mssql
        drop_constraint(Sequel::Model.db.default_constraint_name('APPS', 'INSTANCES'))
      end
      set_column_default :instances, 1
    end
  end

  down do
    alter_table :apps do
      if Sequel::Model.db.database_type == :mssql
        drop_constraint(Sequel::Model.db.default_constraint_name('APPS', 'INSTANCES'))
      end
      set_column_default :instances, 0
    end
  end
end
