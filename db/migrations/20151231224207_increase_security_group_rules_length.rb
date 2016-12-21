Sequel.migration do
  up do
    alter_table :security_groups do
      if Sequel::Model.db.adapter_scheme == :postgres
        set_column_type :rules, :text
      elsif Sequel::Model.db.database_type == :mssql
        set_column_type :rules, 'nvarchar(max)'
      else
        set_column_type :rules, :mediumtext
      end
    end
  end

  down do
    alter_table :security_groups do
      set_column_type :rules, 'varchar(2048)'
    end
  end
end
