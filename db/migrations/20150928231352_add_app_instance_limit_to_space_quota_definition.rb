Sequel.migration do
  change do
    add_column :space_quota_definitions, :app_instance_limit, Integer, default: -1
  end
end
