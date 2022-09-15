Sequel.migration do
  change do
    # This table is unused since CAPI 1.120.0 (Oct. 2021).
    drop_table?(:request_counts)
  end
end
