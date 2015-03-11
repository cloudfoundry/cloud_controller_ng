Sequel.migration do
  change do
    alter_table :space_quota_definitions do
      add_column :disk_limit, Integer, null: false
    end
  end
end
