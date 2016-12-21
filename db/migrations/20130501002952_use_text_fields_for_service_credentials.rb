Sequel.migration do
  change do
    alter_table :service_instances do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :credentials, String, size: :max
      else
        set_column_type :credentials, String, text: true
      end
    end

    alter_table :service_bindings do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :credentials, String, size: :max
      else
        set_column_type :credentials, String, text: true
      end
    end
  end
end
