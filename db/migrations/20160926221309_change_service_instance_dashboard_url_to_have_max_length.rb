Sequel.migration do
  change do
    alter_table :service_instances do
      set_column_type :dashboard_url, String, size: 16_000
    end
  end
end
