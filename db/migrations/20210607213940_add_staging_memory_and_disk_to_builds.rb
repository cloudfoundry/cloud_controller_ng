Sequel.migration do
  change do
    alter_table :builds do
      add_column :staging_memory_in_mb, Integer, default: nil
      add_column :staging_disk_in_mb, Integer, default: nil
    end
  end
end
