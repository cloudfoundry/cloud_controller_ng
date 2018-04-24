Sequel.migration do
  change do
    alter_table :buildpack_lifecycle_buildpacks do
      add_column :version, String, size: 255
      add_column :buildpack_name, String, size: 2047 # Name given by staging callback
    end
  end
end
