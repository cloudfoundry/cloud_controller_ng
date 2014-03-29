Sequel.migration do
  change do
    add_column :apps, :detected_buildpack_guid, String
  end
end
