Sequel.migration do
  change do
    add_column :apps, :staging_failed_reason, String
  end
end
