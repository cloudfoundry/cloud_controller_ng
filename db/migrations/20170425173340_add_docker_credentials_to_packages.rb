Sequel.migration do
  change do
    add_column :packages, :docker_username, String
    add_column :packages, :docker_password_salt, String
    add_column :packages, :encrypted_docker_password, String
  end
end
