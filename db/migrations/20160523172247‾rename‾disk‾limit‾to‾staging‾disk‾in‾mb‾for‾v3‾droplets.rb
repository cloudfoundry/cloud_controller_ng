Sequel.migration do
  change do
    alter_table :v3_droplets do
      rename_column :disk_limit, :staging_disk_in_mb
    end
  end
end
