Sequel.migration do
  up do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
          DECLARE  @dropconstraintsql NVARCHAR(MAX);
          SELECT @dropconstraintsql = 'ALTER TABLE services'
              + ' DROP CONSTRAINT ' + name + ';'
              FROM sys.default_constraints
              where [parent_object_id] = OBJECT_ID(N'services') and [parent_column_id] = COLUMNPROPERTY(OBJECT_ID(N'services'),(N'provider'),'ColumnId')
          EXEC sp_executeSQL @dropconstraintsql
        SQL
    end

    alter_table :services do
      set_column_default :provider, ''
    end
  end

  down do
    # no-op
  end
end
