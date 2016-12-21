Sequel.migration do
  up do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
          DECLARE  @dropconstraintsql NVARCHAR(MAX);
          SELECT @dropconstraintsql = 'ALTER TABLE apps'
              + ' DROP CONSTRAINT ' + name + ';'
              FROM sys.default_constraints
              where [parent_object_id] = OBJECT_ID(N'apps') and [parent_column_id] = COLUMNPROPERTY(OBJECT_ID(N'apps'),(N'memory'),'ColumnId')
          EXEC sp_executeSQL @dropconstraintsql
        SQL
    end

    alter_table(:apps) do
      set_column_default :memory, nil
    end
  end

  down do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
          DECLARE  @dropconstraintsql NVARCHAR(MAX);
          SELECT @dropconstraintsql = 'ALTER TABLE apps'
              + ' DROP CONSTRAINT ' + name + ';'
              FROM sys.default_constraints
              where [parent_object_id] = OBJECT_ID(N'apps') and [parent_column_id] = COLUMNPROPERTY(OBJECT_ID(N'apps'),(N'memory'),'ColumnId')
          EXEC sp_executeSQL @dropconstraintsql
        SQL
    end

    alter_table(:apps) do
      set_column_default :memory, 256
    end
  end
end
