Sequel.migration do
  up do
    alter_table(:deployments) do
      add_column :memory_in_mb, :integer, null: true
    end
  end
  down do
    alter_table(:deployments) do
      drop_column :memory_in_mb
    end
  end
end
