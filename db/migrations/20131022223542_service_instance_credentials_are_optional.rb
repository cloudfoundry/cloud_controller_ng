Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      run <<-SQL
      ALTER TABLE [dbo].[SERVICE_INSTANCES] ALTER COLUMN [CREDENTIALS] VARCHAR (MAX) NULL;
      SQL
    else
      alter_table :service_instances do
        set_column_allow_null :credentials
      end
    end
  end
end
