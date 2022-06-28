Sequel.migration do
  change do
    alter_table(:sidecar_process_types) do
      add_column :app_guid, String, size: 255, null: false
    end
  end
end
