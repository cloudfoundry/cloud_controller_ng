Sequel.migration do
  change do
    add_column :space_quota_definitions, :total_service_keys, Integer, null: false, default: -1
  end
end
