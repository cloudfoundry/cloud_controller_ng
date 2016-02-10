Sequel.migration do
  change do
    add_column :quota_definitions, :app_task_limit, Integer, default: -1
  end
end
