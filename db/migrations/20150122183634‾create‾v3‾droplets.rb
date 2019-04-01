Sequel.migration do
  change do
    create_table :v3_droplets do
      VCAP::Migration.common(self)
      String :state, null: false
      String :buildpack_guid
      index :buildpack_guid, name: 'bp_guid'
      String :package_guid
      index :package_guid
      String :droplet_hash
      String :buildpack_git_url
    end
  end
end
