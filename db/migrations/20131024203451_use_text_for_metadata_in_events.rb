Sequel.migration do
  up do
    # Migrations send missing methods to an instance of Sequel::Database.
    # All the old data in the events table is considered invalid, so chop it off.\
    self[:events].truncate
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
          DECLARE  @dropconstraintsql NVARCHAR(MAX);
          SELECT @dropconstraintsql = 'ALTER TABLE events'
              + ' DROP CONSTRAINT ' + name + ';'
              FROM sys.default_constraints
              where [parent_object_id] = OBJECT_ID(N'events') and [parent_column_id] = COLUMNPROPERTY(OBJECT_ID(N'events'),(N'metadata'),'ColumnId')
          EXEC sp_executeSQL @dropconstraintsql
      SQL
    end

    alter_table(:events) do
      set_column_allow_null :metadata
      set_column_default :metadata, nil
      if Sequel::Model.db.database_type == :mssql
        set_column_type :metadata, String, size: :max
      else
        set_column_type :metadata, String, text: 'true'
      end
    end
  end

  down do
    # The current data in events is invalid with regard to the old schema, so truncate here too.
    self[:events].truncate

    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
          DECLARE  @dropconstraintsql NVARCHAR(MAX);
          SELECT @dropconstraintsql = 'ALTER TABLE events'
              + ' DROP CONSTRAINT ' + name + ';'
              FROM sys.default_constraints
              where [parent_object_id] = OBJECT_ID(N'events') and [parent_column_id] = COLUMNPROPERTY(OBJECT_ID(N'events'),(N'metadata'),'ColumnId')
          EXEC sp_executeSQL @dropconstraintsql
      SQL
    end

    alter_table(:events) do
      set_column_type :metadata, String
      set_column_default :metadata, '{}'
      set_column_not_null :metadata
    end
  end
end
