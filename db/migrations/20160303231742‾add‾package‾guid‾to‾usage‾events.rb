Sequel.migration do
  change do
    add_column :app_usage_events, :package_guid, String, default: nil
  end
end
