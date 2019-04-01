Sequel.migration do
  change do
    alter_table :packages do
      set_column_type :encrypted_docker_password, String, size: 16_000
    end
  end
end
