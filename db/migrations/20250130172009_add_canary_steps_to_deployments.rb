Sequel.migration do
  up do
    alter_table(:deployments) do
      add_column :canary_steps, String, size: 4096
      add_column :canary_current_step, :integer
    end
  end
  down do
    alter_table(:deployments) do
      drop_column :canary_steps
      drop_column :canary_current_step
    end
  end
end
