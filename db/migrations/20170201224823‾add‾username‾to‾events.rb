Sequel.migration do
  change do
    add_column :events, :actor_username, String
  end
end
