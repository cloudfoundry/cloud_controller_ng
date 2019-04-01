Sequel.migration do
  change do
    add_column :delayed_jobs, :cf_api_error, String, text: true
  end
end
