Sequel.migration do
  up do
    drop_index :delayed_jobs, %i[queue locked_at failed_at run_at], name: :delayed_jobs_reserve
    add_index :delayed_jobs, %i[queue locked_at locked_by failed_at run_at], name: :delayed_jobs_reserve
  end

  down do
    drop_index :delayed_jobs, %i[queue locked_at locked_by failed_at run_at], name: :delayed_jobs_reserve
    add_index :delayed_jobs, %i[queue locked_at failed_at run_at], name: :delayed_jobs_reserve
  end
end
