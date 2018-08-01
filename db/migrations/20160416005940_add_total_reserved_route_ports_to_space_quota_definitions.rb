Sequel.migration do
  change do
    add_column :space_quota_definitions, :total_reserved_route_ports, Integer, default: -1
  end
end
