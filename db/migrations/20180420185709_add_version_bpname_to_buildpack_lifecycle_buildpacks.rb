Sequel.migration do
  change do
    alter_table :buildpack_lifecycle_buildpacks do
      add_column :version, String
      add_column :buildpack_name, String # Name given by staging callback
    end
  end
end
