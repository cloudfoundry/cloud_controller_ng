Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
            DECLARE  @dropconstraintsql NVARCHAR(MAX);
            SELECT @dropconstraintsql = 'ALTER TABLE apps'
                + ' DROP CONSTRAINT ' + name + ';'
                FROM sys.default_constraints
                where [parent_object_id] = OBJECT_ID(N'apps') and [parent_column_id] = COLUMNPROPERTY(OBJECT_ID(N'apps'),(N'max_task_sequence_id'),'ColumnId')
            EXEC sp_executeSQL @dropconstraintsql
      SQL
    end

    alter_table(:apps) do
      set_column_default(:max_task_sequence_id, 1)
    end
  end
end
