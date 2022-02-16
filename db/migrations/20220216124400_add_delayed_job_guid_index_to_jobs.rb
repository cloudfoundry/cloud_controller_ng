Sequel.migration do
  up do
    alter_table :jobs do
      add_index :delayed_job_guid, name: :jobs_delayed_job_guid_index
    end
  end

  down do
    alter_table :jobs do
      drop_index :delayed_job_guid, name: :jobs_delayed_job_guid_index
    end
  end
end
