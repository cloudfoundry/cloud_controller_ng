Sequel.migration do
  change do
    alter_table :v3_droplets do
      if Sequel::Model.db.database_type == :mssql
        rename_column :disk_limit, 'STAGING_DISK_IN_MB'
      else
        rename_column :disk_limit, :staging_disk_in_mb
      end
    end
  end
end
