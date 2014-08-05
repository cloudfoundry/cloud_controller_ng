Sequel.migration do
  change do
    add_column :apps, :docker_image, String, text: true
  end
end
