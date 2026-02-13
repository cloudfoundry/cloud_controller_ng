Sequel.migration do
  no_transaction # to use the 'concurrently' option

  up do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :app_usage_events, %i[state app_guid id],
                  name: :app_usage_events_lifecycle_index,
                  if_not_exists: true,
                  concurrently: true

        add_index :service_usage_events, %i[state service_instance_guid id],
                  name: :service_usage_events_lifecycle_index,
                  if_not_exists: true,
                  concurrently: true
      end

    elsif database_type == :mysql
      alter_table :app_usage_events do
        # rubocop:disable Sequel/ConcurrentIndex
        add_index %i[state app_guid id], name: :app_usage_events_lifecycle_index unless @db.indexes(:app_usage_events).include?(:app_usage_events_lifecycle_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end

      alter_table :service_usage_events do
        # rubocop:disable Sequel/ConcurrentIndex
        unless @db.indexes(:service_usage_events).include?(:service_usage_events_lifecycle_index)
          add_index %i[state service_instance_guid id],
                    name: :service_usage_events_lifecycle_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :app_usage_events, %i[state app_guid id],
                   name: :app_usage_events_lifecycle_index,
                   if_exists: true,
                   concurrently: true

        drop_index :service_usage_events, %i[state service_instance_guid id],
                   name: :service_usage_events_lifecycle_index,
                   if_exists: true,
                   concurrently: true
      end
    end

    if database_type == :mysql
      alter_table :app_usage_events do
        # rubocop:disable Sequel/ConcurrentIndex
        drop_index %i[state app_guid id], name: :app_usage_events_lifecycle_index if @db.indexes(:app_usage_events).include?(:app_usage_events_lifecycle_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end

      alter_table :service_usage_events do
        # rubocop:disable Sequel/ConcurrentIndex
        if @db.indexes(:service_usage_events).include?(:service_usage_events_lifecycle_index)
          drop_index %i[state service_instance_guid id],
                     name: :service_usage_events_lifecycle_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
