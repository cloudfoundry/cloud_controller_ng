Sequel.migration do
  up do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
          DECLARE  @dropconstraintsql NVARCHAR(MAX);
          SELECT @dropconstraintsql = 'ALTER TABLE apps'
              + ' DROP CONSTRAINT ' + name + ';'
              FROM sys.default_constraints
              where [parent_object_id] = OBJECT_ID(N'apps') and [parent_column_id] = COLUMNPROPERTY(OBJECT_ID(N'apps'),(N'instances'),'ColumnId')
          EXEC sp_executeSQL @dropconstraintsql
        SQL
    end
    alter_table :apps do
      set_column_default :instances, 1
    end
  end

  down do
    alter_table :apps do
      set_column_default :instances, 0
    end
  end
end
