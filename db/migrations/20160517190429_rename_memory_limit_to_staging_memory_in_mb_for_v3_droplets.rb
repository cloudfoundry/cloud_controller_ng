Sequel.migration do
  change do
    alter_table :v3_droplets do
      if Sequel::Model.db.database_type == :mssql
        rename_column :memory_limit, 'STAGING_MEMORY_IN_MB'
      else
        rename_column :memory_limit, :staging_memory_in_mb
      end
    end
  end
end
