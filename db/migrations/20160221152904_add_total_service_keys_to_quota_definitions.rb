Sequel.migration do
  change do
    add_column :quota_definitions, :total_service_keys, Integer, default: -1
  end
end
