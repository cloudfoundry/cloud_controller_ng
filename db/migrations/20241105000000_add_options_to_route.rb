Sequel.migration do
  up do
    alter_table(:routes) do
      # rubocop:disable Migration/IncludeStringSize
      add_column :options, String, text: true, default: nil
      # rubocop:enable Migration/IncludeStringSize
    end
  end
  down do
    alter_table(:routes) do
      drop_column :options
    end
  end
end
