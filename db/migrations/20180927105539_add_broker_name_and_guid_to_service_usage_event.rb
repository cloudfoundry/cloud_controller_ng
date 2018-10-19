Sequel.migration do
  change do
    # As service broker name is stored as 'String' (with no length
    # limit specified) in the service_brokers table, we have to use the same
    # field type here.
    # For the guid we have control, so we explicitly set a limit.

    # rubocop:disable Migration/IncludeStringSize
    add_column :service_usage_events, :service_broker_name, String, null: true
    # rubocop:enable Migration/IncludeStringSize
    add_column :service_usage_events, :service_broker_guid, String, null: true, size: 255
  end
end
