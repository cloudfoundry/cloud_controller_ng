Sequel.migration do
  up do
    # rubocop:disable Rails/CreateTableWithTimestamps
    create_table(:cnb_lifecycle_data) do
      VCAP::Migration.common(self, :cnb_lifecycle_data)

      String :build_guid, size: 255
      foreign_key [:build_guid], :builds, key: :guid, name: :fk_cnb_lifecycle_build_guid, on_delete: :cascade
      index [:build_guid], name: :fk_cnb_lifecycle_build_guid_index

      String :app_guid, size: 255
      index [:app_guid], name: :fk_cnb_lifecycle_app_guid_index

      String :droplet_guid, size: 255
      index [:droplet_guid], name: :fk_cnb_lifecycle_droplet_guid_index

      String :stack, size: 255
    end
    # rubocop:enable Rails/CreateTableWithTimestamps

    alter_table(:buildpack_lifecycle_buildpacks) do
      # rubocop:disable Migration:IncludeStringSize
      add_column :cnb_lifecycle_data_guid, String
      # rubocop:enable Migration:IncludeStringSize

      add_foreign_key [:cnb_lifecycle_data_guid], :cnb_lifecycle_data, key: :guid, name: :fk_blcnb_bldata_guid, on_delete: :cascade
      # rubocop:disable Sequel/ConcurrentIndex
      add_index :cnb_lifecycle_data_guid, name: :bl_cnb_bldata_guid_index
      # rubocop:enable Sequel/ConcurrentIndex
    end
  end

  down do
    alter_table(:buildpack_lifecycle_buildpacks) do
      drop_foreign_key [:cnb_lifecycle_data_guid]
      # rubocop:disable Sequel/ConcurrentIndex
      drop_index :cnb_lifecycle_data_guid, name: :bl_cnb_bldata_guid_index
      # rubocop:enable Sequel/ConcurrentIndex
      drop_column :cnb_lifecycle_data_guid
    end

    drop_table :cnb_lifecycle_data
  end
end
