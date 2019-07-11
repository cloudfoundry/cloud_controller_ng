Sequel.migration do
  change do
    alter_table(:deployments) do
      add_column :status_value, String, size: 255
      add_column :status_reason, String, size: 255, null: true
    end
  end
end
