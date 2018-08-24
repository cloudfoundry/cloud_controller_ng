Sequel.migration do
  change do
    alter_table :droplets do
      set_column_type :encrypted_docker_receipt_password, String, size: 16_000
    end
  end
end
