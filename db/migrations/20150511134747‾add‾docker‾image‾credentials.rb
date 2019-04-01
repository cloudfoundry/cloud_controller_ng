Sequel.migration do
  change do
    alter_table :apps do
      add_column :encrypted_docker_credentials_json, String
      add_column :docker_salt, String
    end
  end
end
