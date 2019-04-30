Sequel.migration do
  change do
    alter_table(:deployments) do
      add_column :last_healthy_at, DateTime, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
