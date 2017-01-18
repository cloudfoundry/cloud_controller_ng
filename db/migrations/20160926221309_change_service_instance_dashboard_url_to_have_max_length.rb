Sequel.migration do
  change do
    alter_table :service_instances do
      if Sequel::Model.db.database_type == :mssql
        set_column_type :dashboard_url, String, size: :max
      else
        set_column_type :dashboard_url, String, size: 16_000
      end
    end
  end
end
