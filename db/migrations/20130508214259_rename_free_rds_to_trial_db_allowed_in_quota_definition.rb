Sequel.migration do
  change do
    alter_table :quota_definitions do
      rename_column :free_rds, :trial_db_allowed
    end
  end
end
