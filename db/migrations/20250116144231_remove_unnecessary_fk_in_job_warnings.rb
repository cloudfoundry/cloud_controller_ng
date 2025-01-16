Sequel.migration do
  up do
    unless foreign_key_list(:job_warnings).empty?
      alter_table :job_warnings do
        drop_foreign_key :fk_jobs_id
      end
    end
  end
end
