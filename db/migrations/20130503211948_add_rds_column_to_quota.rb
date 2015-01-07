Sequel.migration do
  change do
    alter_table :quota_definitions do
      add_column :free_rds, TrueClass, default: false
    end
  end
end
