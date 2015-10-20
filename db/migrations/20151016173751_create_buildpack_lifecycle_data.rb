Sequel.migration do
  change do
    create_table :buildpack_lifecycle_data do
      VCAP::Migration.common(self, :buildpack_lifecycle_data)

      String :app_guid
      index :app_guid, name: :buildpack_lifecycle_data_app_guid

      String :droplet_guid
      index :droplet_guid, name: :bp_lifecycle_data_droplet_guid

      String :stack
      String :buildpack
    end
  end
end
