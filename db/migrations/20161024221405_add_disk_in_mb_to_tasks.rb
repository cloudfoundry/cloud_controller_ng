Sequel.migration do
  change do
    add_column :tasks, :disk_in_mb, Integer
  end
end
