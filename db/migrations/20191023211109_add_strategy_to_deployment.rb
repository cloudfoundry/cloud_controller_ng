Sequel.migration do
  change do
    alter_table(:deployments) do
      add_column :strategy, String, null: false, default: 'rolling', size: 255
    end
  end
end
