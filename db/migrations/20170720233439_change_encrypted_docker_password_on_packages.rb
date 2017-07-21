Sequel.migration do
  change do
    alter_table :packages do
      set_column_type :encrypted_docker_password, String, text: true
    end
  end
end
