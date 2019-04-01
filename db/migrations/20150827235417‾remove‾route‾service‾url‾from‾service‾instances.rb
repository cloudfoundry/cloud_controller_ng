Sequel.migration do
  change do
    drop_column :service_instances, :route_service_url
  end
end
