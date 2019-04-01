Sequel.migration do
  change do
    add_column :jobs, :cf_api_error, String, size: 16_000, null: true
  end
end
