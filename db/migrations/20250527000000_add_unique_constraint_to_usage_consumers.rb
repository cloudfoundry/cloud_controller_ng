Sequel.migration do
  change do
    alter_table :app_usage_consumers do
      add_index :consumer_guid, unique: true, name: :app_usage_consumers_consumer_guid_unique
      add_index :last_processed_guid, name: :app_usage_consumers_last_processed_guid_index
    end

    alter_table :service_usage_consumers do
      add_index :consumer_guid, unique: true, name: :service_usage_consumers_consumer_guid_unique
      add_index :last_processed_guid, name: :service_usage_consumers_last_processed_guid_index
    end
  end
end
