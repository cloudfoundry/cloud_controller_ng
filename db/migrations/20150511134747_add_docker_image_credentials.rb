Sequel.migration do
  change do
    alter_table :apps do
      add_column :encrypted_docker_user, String
      add_column :encrypted_docker_password, String
      add_column :encrypted_docker_email, String
      add_column :docker_salt, String
    end
  end
end
