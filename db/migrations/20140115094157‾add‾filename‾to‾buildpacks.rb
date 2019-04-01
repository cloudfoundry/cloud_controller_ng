Sequel.migration do
  change do
    add_column :buildpacks, :filename, String
  end
end
