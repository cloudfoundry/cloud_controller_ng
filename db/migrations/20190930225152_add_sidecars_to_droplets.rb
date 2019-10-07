Sequel.migration do
  change do
    alter_table :droplets do
      # rubocop:disable Migration/IncludeStringSize
      add_column :sidecars, String, text: true, default: nil
      # rubocop:enable Migration/IncludeStringSize
    end
  end
end
