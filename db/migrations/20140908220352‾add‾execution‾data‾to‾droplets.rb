Sequel.migration do
  change do
    add_column :droplets, :execution_metadata, String
  end
end
