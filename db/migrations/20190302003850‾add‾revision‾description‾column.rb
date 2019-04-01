Sequel.migration do
  change do
    alter_table(:revisions) do
      # rubocop:disable Migration/IncludeStringSize
      add_column :description, String, text: true, default: 'N/A', null: false
      # rubocop:enable Migration/IncludeStringSize
    end
  end
end
