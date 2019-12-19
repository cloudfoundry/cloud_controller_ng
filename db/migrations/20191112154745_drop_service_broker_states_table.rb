Sequel.migration do
  up do
    # The endpoint that used this table has always been experimental
    drop_table?(:service_broker_states)
  end

  down do
    # This migration cannot be reversed
  end
end
