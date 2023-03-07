Sequel.migration do
  change do
    drop_column :droplets, :encrypted_environment_variables
    drop_column :droplets, :salt
  end
end
