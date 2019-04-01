Sequel.migration do
  change do
    add_column :apps, :detected_buildpack_name, String
  end
end
