Sequel.migration do
  change do
    add_column :space_quota_definitions, :app_task_limit, Integer, default: 5
  end
end
