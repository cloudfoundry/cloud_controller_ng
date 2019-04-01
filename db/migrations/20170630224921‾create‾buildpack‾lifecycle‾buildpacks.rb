Sequel.migration do
  change do
    create_table :buildpack_lifecycle_buildpacks do
      VCAP::Migration.common(self, :buildpack_lifecycle_buildpacks)

      String :admin_buildpack_name
      String :encrypted_buildpack_url, size: 16_000
      String :encrypted_buildpack_url_salt
      String :buildpack_lifecycle_data_guid

      foreign_key [:buildpack_lifecycle_data_guid], :buildpack_lifecycle_data, key: :guid, name: :fk_blbuildpack_bldata_guid
      index [:buildpack_lifecycle_data_guid], name: :bl_buildpack_bldata_guid_index
    end
  end
end
