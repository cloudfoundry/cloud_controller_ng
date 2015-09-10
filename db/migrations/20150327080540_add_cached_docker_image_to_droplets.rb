Sequel.migration do
  change do
    add_column :droplets, :cached_docker_image, String
  end
end
