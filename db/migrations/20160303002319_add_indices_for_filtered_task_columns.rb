Sequel.migration do
  change do
    add_index :tasks, :state
    add_index :tasks, :name
  end
end
