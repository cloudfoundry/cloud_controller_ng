Sequel.migration do
  change do
    add_column :app_usage_events, :task_guid, String, null: true
    add_column :app_usage_events, :task_name, String, null: true
  end
end
