Sequel.migration do
  change do
    alter_table(:sidecar_process_types) do
      rename_column :name, :type
    end
  end
end
