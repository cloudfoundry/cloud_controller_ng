Sequel.migration do
  change do
    alter_table :deployments do
      add_index :state, name: :deployments_state_index
    end
  end
end
