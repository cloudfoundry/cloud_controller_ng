Sequel.migration do
  change do
    add_column :droplets, :docker_receipt_username, String
    add_column :droplets, :docker_receipt_password_salt, String
    add_column :droplets, :encrypted_docker_receipt_password, String
  end
end
