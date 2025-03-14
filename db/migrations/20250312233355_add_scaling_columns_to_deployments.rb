Sequel.migration do
  up do
    alter_table(:deployments) do
      add_column :memory_in_mb, :integer, null: true
      add_column :disk_in_mb, :integer, null: true
      add_column :log_rate_limit_in_bytes_per_second, :integer, null: true
    end
  end
  down do
    alter_table(:deployments) do
      drop_column :memory_in_mb
      drop_column :disk_in_mb
      drop_column :log_rate_limit_in_bytes_per_second
    end
  end
end
