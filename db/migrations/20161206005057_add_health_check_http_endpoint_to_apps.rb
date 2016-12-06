Sequel.migration do
  change do
    alter_table :apps do
      add_column :health_check_http_endpoint, String, text: true
    end
  end
end
