Sequel.migration do
  change do
    add_column :events, :actor_name, String
    add_column :events, :actee_name, String
  end
end
