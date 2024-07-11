Sequel.migration do
  up do
    alter_table(:deployments) do
      add_column :status_updated_at, DateTime, default: Sequel::CURRENT_TIMESTAMP, null: false
    end
    run 'update deployments set status_updated_at = updated_at where updated_at is not null'
  end

  down do
    alter_table(:deployments) do
      drop_column :status_updated_at
    end
  end
end
