Sequel.migration do
  change do
    alter_table :kpack_lifecycle_data do
      add_column :buildpacks, String, size: 5000, default: Oj.dump([])
    end
  end
end
