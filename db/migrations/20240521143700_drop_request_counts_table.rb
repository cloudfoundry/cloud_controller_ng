Sequel.migration do
  up do
    # This table is unused since CAPI 1.120.0 (Oct. 2021).
    # The model class has been removed with CAPI 1.140.0 (Oct. 2022).
    drop_table?(:request_counts)
  end

  down do
    # This migration is irreversible.
  end
end
