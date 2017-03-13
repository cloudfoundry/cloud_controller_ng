Sequel.migration do
  change do
    if Sequel::Model.db.database_type == :mssql
      add_column :delayed_jobs, :cf_api_error, String, size: :max
    else
      add_column :delayed_jobs, :cf_api_error, String, text: true
    end
  end
end
