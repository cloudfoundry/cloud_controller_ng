Sequel.migration do
  up do
    add_index :delayed_jobs, %i[queue locked_at locked_by failed_at run_at], name: :delayed_jobs_reserve_where
  end

  down do
    drop_index :delayed_jobs, nil, name: :delayed_jobs_reserve_where
  end
end
