Sequel.migration do
  up do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
          DECLARE  @dropconstraintsql NVARCHAR(MAX);
          SELECT @dropconstraintsql = 'ALTER TABLE apps'
              + ' DROP CONSTRAINT ' + name + ';'
              FROM sys.default_constraints
              where [parent_object_id] = OBJECT_ID(N'apps') and [parent_column_id] = COLUMNPROPERTY(OBJECT_ID(N'apps'),(N'metadata'),'ColumnId')
          EXEC sp_executeSQL @dropconstraintsql
      SQL
    end
    alter_table :apps do
      set_column_type :metadata, String, size: 4096
      set_column_default :metadata, '{}'
    end
  end

  down do
    alter_table :apps do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :metadata, String, size: :max
      else
        set_column_type :metadata, String, text: true
      end
    end
  end
end
