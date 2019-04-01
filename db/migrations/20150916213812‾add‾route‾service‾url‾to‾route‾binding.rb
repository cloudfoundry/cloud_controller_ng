Sequel.migration do
  change do
    add_column :route_bindings, :route_service_url, String, default: nil
  end
end
