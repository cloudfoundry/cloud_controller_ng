Sequel.migration do
  change do
    alter_table :quota_definitions do
      add_column :app_instance_limit, Integer, default: -1
    end
  end
end
