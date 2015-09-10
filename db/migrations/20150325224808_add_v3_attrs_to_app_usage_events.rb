Sequel.migration do
  change do
    add_column :app_usage_events, :parent_app_name, String
    add_column :app_usage_events, :parent_app_guid, String
    add_column :app_usage_events, :process_type, String
  end
end
