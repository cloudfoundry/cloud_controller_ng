Sequel.migration do
  change do
    alter_table :deployments do
      add_index :status_value, name: :deployments_status_value_index
      add_index :status_reason, name: :deployments_status_reason_index
    end
  end
end
