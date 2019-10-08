Sequel.migration do
  change do
    create_table(:job_warnings) do
      VCAP::Migration.common(self)

      String :detail, size: 16000, null: false

      Integer :job_id, null: false
      foreign_key :job_id, :jobs, name: :fk_jobs_id
      index [:job_id], name: :fk_jobs_id_index
    end
  end
end
