Sequel.migration do
  change do
    add_column :tasks, :failure_reason, String, null: true, size: 4096
  end
end
