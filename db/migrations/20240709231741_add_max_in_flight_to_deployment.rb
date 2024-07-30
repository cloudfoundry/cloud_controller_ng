Sequel.migration do
  change do
    alter_table(:deployments) do
      add_column :max_in_flight, Integer, null: false, default: 1
    end
  end
end
