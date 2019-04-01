Sequel.migration do
  change do
    drop_table :service_instance_dashboard_clients
  end
end
