Sequel.migration do
  change do
    create_table(:kpack_lifecycle_data) do
      VCAP::Migration.common(self)

      String :build_guid, size: 255, null: false
      foreign_key [:build_guid], :builds, key: :guid, name: :fk_kpack_lifecycle_build_guid
      index [:build_guid], name: :fk_kpack_lifecycle_build_guid_index

      String :droplet_guid, size: 255
    end
  end
end
