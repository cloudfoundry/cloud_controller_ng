Sequel.migration do
  change do
    alter_table :packages do
      add_index :state, name: :packages_state_index
    end
  end
end
