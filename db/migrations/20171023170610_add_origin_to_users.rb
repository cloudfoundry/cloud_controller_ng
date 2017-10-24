Sequel.migration do
  change do
    add_column :users, :origin, String, null: true
  end
end
