Sequel.migration do
  change do
    add_column :quota_definitions, :total_reserved_route_ports, Integer, default: 0
  end
end
