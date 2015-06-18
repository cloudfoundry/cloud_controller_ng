Sequel.migration do
  change do
    add_column :apps, :staging_failed_description, String
  end
end
