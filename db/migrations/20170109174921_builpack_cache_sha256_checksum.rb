Sequel.migration do
  change do
    alter_table :apps do
      add_column :buildpack_cache_sha256_checksum, String, null: true
    end
  end
end
