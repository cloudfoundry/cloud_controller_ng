Sequel.migration do
  change do
    add_column :app_usage_events, :package_state, String
  end
end
