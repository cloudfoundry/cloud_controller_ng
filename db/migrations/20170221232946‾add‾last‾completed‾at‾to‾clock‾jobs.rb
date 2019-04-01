Sequel.migration do
  change do
    alter_table :clock_jobs do
      add_column :last_completed_at, DateTime
    end
  end
end
