Sequel.migration do
  change do
    alter_table :service_instances do
      add_column :dashboard_url, String
    end
  end
end
