Sequel.migration do
  up do
    alter_table(:deployments) do
      add_column :web_instances, :integer, null: true
    end
  end
  down do
    alter_table(:deployments) do
      drop_column :web_instances
    end
  end
end
