Sequel.migration do
  change do
    rename_column(:billing_events, :timestamp, :event_timestamp)

    rename_column(:app_events, :timestamp, :event_timestamp)

    rename_column(:events, :timestamp, :event_timestamp)
  end
end
