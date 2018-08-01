Sequel.migration do
  change do
    alter_table :droplets do
      add_column :sha256_checksum, String, null: true
    end
    add_index :droplets, :sha256_checksum
  end
end
