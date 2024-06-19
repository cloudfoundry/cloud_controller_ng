Sequel.migration do
  # adding an index concurrently cannot be done within a transaction
  no_transaction

  up do
    transaction do
      create_table?(:cnb_lifecycle_data) do
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

      add_column :buildpack_lifecycle_buildpacks, :cnb_lifecycle_data_guid, String, size: 255, if_not_exists: true
      if foreign_key_list(:buildpack_lifecycle_buildpacks).none? { |fk| fk[:name] == :fk_blcnb_bldata_guid }
        alter_table(:buildpack_lifecycle_buildpacks) do
          add_foreign_key [:cnb_lifecycle_data_guid], :cnb_lifecycle_data, key: :guid, name: :fk_blcnb_bldata_guid, on_delete: :cascade
        end
      end
    end

    VCAP::Migration.with_concurrent_timeout(self) do
      add_index :buildpack_lifecycle_buildpacks, :cnb_lifecycle_data_guid, name: :bl_cnb_bldata_guid_index, if_not_exists: true, concurrently: true if database_type == :postgres
    end
  end

  down do
    VCAP::Migration.with_concurrent_timeout(self) do
      drop_index :buildpack_lifecycle_buildpacks, :cnb_lifecycle_data_guid, name: :bl_cnb_bldata_guid_index, if_exists: true, concurrently: true if database_type == :postgres
    end

    transaction do
      if foreign_key_list(:buildpack_lifecycle_buildpacks).any? { |fk| fk[:name] == :fk_blcnb_bldata_guid }
        alter_table(:buildpack_lifecycle_buildpacks) do
          drop_foreign_key [:cnb_lifecycle_data_guid] if @db.foreign_key_list(:buildpack_lifecycle_buildpacks)
        end
      end
      drop_column :buildpack_lifecycle_buildpacks, :cnb_lifecycle_data_guid, if_exists: true
      drop_table? :cnb_lifecycle_data
    end
  end
end
