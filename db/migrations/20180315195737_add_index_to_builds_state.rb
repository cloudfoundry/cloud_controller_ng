Sequel.migration do
  change do
    alter_table :builds do
      add_index :state, name: :builds_state_index
    end
  end
end
