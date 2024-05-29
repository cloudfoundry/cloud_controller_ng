Sequel.migration do
  # adding an index concurrently cannot be done within a transaction
  no_transaction

  up do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :app_usage_events, :task_guid, name: :app_usage_events_task_guid_index, if_not_exists: true, concurrently: true
      end

    elsif database_type == :mysql
      alter_table :app_usage_events do
        # rubocop:disable Sequel/ConcurrentIndex
        add_index :task_guid, name: :app_usage_events_task_guid_index unless @db.indexes(:app_usage_events).include?(:app_usage_events_task_guid_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :app_usage_events, :task_guid, name: :app_usage_events_task_guid_index, if_exists: true, concurrently: true
      end
    end

    if database_type == :mysql
      alter_table :app_usage_events do
        # rubocop:disable Sequel/ConcurrentIndex
        drop_index :task_guid, name: :app_usage_events_task_guid_index if @db.indexes(:app_usage_events).include?(:app_usage_events_task_guid_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
