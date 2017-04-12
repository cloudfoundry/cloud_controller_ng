Sequel.migration do
  change do
    alter_table :processes do
      if Sequel::Model.db.database_type == :mssql
        add_column :health_check_http_endpoint, String, size: :max
      else
        add_column :health_check_http_endpoint, String, text: true
      end
    end
  end
end
