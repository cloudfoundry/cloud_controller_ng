Sequel.migration do
  change do
    alter_table :buildpacks do
      add_column :sha256_checksum, String, null: true
    end
  end
end
