Sequel.migration do
  change do
    alter_table :app_usage_events do
      add_index :task_guid, name: :app_usage_events_task_guid_index
    end
  end
end
