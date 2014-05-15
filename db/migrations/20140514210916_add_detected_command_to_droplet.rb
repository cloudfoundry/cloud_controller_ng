Sequel.migration do
  change do
    add_column :droplets, :detected_start_command, String
  end
end
