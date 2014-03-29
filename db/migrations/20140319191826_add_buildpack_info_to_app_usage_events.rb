Sequel.migration do
  change do
    add_column :app_usage_events, :buildpack_guid, String
    add_column :app_usage_events, :buildpack_name, String
  end
end
