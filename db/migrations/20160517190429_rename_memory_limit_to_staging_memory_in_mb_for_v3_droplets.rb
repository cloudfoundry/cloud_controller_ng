Sequel.migration do
  change do
    alter_table :v3_droplets do
      rename_column :memory_limit, :staging_memory_in_mb
    end
  end
end
