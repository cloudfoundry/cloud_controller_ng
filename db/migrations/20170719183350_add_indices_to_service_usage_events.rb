Sequel.migration do
  change do
    alter_table :service_usage_events do
      add_index :service_guid, name: :service_usage_events_service_guid_index
      add_index :service_instance_type, name: :service_usage_events_service_instance_type_index
    end
  end
end
