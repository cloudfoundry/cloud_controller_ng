Sequel.migration do
  up do
    alter_table(:routes) do
      add_column :options, String, size: 4096, default: '{}'
    end
  end
  down do
    alter_table(:routes) do
      drop_column :options
    end
  end
end
