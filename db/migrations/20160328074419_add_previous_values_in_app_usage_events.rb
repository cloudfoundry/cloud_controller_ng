Sequel.migration do
  change do
    add_column :app_usage_events, :previous_state, String, default: nil
    add_column :app_usage_events, :previous_package_state, String, default: nil
    add_column :app_usage_events, :previous_memory_in_mb_per_instance, Integer, default: nil
    add_column :app_usage_events, :previous_instance_count, Integer, default: nil
  end
end
