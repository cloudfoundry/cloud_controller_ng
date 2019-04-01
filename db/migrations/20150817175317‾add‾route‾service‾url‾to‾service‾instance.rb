Sequel.migration do
  change do
    add_column :service_instances, :route_service_url, String
  end
end
