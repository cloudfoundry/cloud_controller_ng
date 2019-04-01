Sequel.migration do
  change do
    alter_table(:service_brokers) do
      add_column :encryption_iterations, Integer, default: 2048, null: false
    end
  end
end
