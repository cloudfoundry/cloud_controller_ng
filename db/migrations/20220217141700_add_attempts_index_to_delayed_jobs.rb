Sequel.migration do
  up do
    alter_table :delayed_jobs do
      add_index :attempts, name: :delayed_jobs_attempts_index
    end
  end

  down do
    alter_table :delayed_jobs do
      drop_index :attempts, name: :delayed_jobs_attempts_index
    end
  end
end
