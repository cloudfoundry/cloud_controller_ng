Sequel.migration do
  change do
    # rubocop:disable Migration/IncludeStringSize
    add_column :service_instances, :broker_provided_metadata, String, size: 4096, text: true, null: true
    # rubocop:enable Migration/IncludeStringSize
  end
end
