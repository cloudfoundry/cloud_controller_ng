Sequel.migration do
  change do
    alter_table :v3_droplets do
      drop_column :buildpack_git_url
      add_column :buildpack, String, default: nil
    end
  end
end
