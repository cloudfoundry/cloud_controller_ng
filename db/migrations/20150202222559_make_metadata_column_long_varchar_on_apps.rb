Sequel.migration do
  up do
    alter_table :apps do
      set_column_type :metadata, String, size: 4096
      if Sequel::Model.db.database_type == :mssql
        drop_constraint(Sequel::Model.db.default_constraint_name('APPS', 'METADATA'))
      end
      set_column_default :metadata, '{}'
    end
  end

  down do
    alter_table :apps do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :metadata, String, size: :max
        drop_constraint(Sequel::Model.db.default_constraint_name('APPS', 'METADATA'))
      else
        set_column_type :metadata, String, text: true
      end
    end
  end
end
