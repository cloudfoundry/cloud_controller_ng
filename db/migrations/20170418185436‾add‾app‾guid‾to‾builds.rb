Sequel.migration do
  change do
    add_column :builds, :app_guid, String
  end
end
