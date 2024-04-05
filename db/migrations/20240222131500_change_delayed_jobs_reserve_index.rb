Sequel.migration do
  no_transaction # to use the 'concurrently' option

  up do
    if database_type == :postgres
      drop_index :delayed_jobs, nil, name: :delayed_jobs_reserve, if_exists: true, concurrently: true
      add_index :delayed_jobs, %i[queue locked_at locked_by failed_at run_at priority],
                where: { failed_at: nil }, name: :delayed_jobs_reserve, if_not_exists: true, concurrently: true
    end
  end

  down do
    if database_type == :postgres
      drop_index :delayed_jobs, nil, name: :delayed_jobs_reserve, if_exists: true, concurrently: true
      add_index :delayed_jobs, %i[queue locked_at locked_by failed_at run_at priority],
                name: :delayed_jobs_reserve, if_not_exists: true, concurrently: true
    end
  end
end
