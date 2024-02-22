Sequel.migration do
  up do
    if database_type == :postgres
      drop_index :delayed_jobs, nil, name: :delayed_jobs_reserve, options: %i[if_exists concurrently]
      add_index :delayed_jobs, %i[queue locked_at locked_by failed_at run_at priority],
                where: { failed_at: nil }, name: :delayed_jobs_reserve, options: %i[if_not_exists concurrently]
    end
  end

  down do
    if database_type == :postgres
      drop_index :delayed_jobs, nil, name: :delayed_jobs_reserve, options: %i[if_exists concurrently]
      add_index :delayed_jobs, %i[queue locked_at locked_by failed_at run_at priority],
                name: :delayed_jobs_reserve, options: %i[if_not_exists concurrently]
    end
  end
end
