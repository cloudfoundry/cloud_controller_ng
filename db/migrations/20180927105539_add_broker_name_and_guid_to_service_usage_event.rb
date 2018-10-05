Sequel.migration do
  change do
    # As service broker name and guid are stored as 'String' (with no length
    # limit specified) in the service_brokers table, we have to use the same
    # field type here.

    # rubocop:disable Migration/IncludeStringSize
    add_column :service_usage_events, :service_broker_name, String, null: true
    add_column :service_usage_events, :service_broker_guid, String, null: true
    # rubocop:enable Migration/IncludeStringSize
  end
end
