Sequel.migration do
  change do
    create_table :clock_jobs do
      primary_key :id

      String :name, null: false
      index :name, unique: true, name: 'clock_jobs_name_unique'

      DateTime :last_started_at
    end
  end
end
