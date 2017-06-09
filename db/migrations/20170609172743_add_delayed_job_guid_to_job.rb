Sequel.migration do
  change do
    add_column :jobs, :delayed_job_guid, String
  end
end
