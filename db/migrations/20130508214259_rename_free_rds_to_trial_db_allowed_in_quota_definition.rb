Sequel.migration do
  change do
    alter_table :quota_definitions do
      if Sequel::Model.db.database_type == :mssql
        rename_column :free_rds, 'TRIAL_DB_ALLOWED'
      else
        rename_column :free_rds, :trial_db_allowed
      end
    end
  end
end
