Sequel.migration do
  change do
    add_column :service_instances, :route_service_url, String, default: nil
  end
end
