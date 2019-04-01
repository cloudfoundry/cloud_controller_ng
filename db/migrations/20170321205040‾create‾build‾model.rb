Sequel.migration do
  change do
    create_table :builds do
      VCAP::Migration.common(self)
      String :state
      String :package_guid
      String :buildpack_receipt_buildpack_guid
      String :buildpack_receipt_stack_name
    end

    alter_table :droplets do
      add_column :build_guid, String
      add_index :build_guid, name: :droplet_build_guid_index
    end

    alter_table :buildpack_lifecycle_data do
      add_column :build_guid, String
      add_index :build_guid, name: :buildpack_lifecycle_data_build_guid_index
    end
  end
end
