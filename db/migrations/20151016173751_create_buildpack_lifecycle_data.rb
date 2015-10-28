Sequel.migration do
  up do
    transaction do
      alter_table(:v3_droplets) do
        drop_foreign_key [:app_guid]
      end
      alter_table(:packages) do
        drop_foreign_key [:app_guid]
      end
      alter_table(:apps) do
        drop_foreign_key [:app_guid]
        drop_index :app_guid
      end
      alter_table(:apps_v3_routes) do
        drop_foreign_key :app_v3_id
      end

      run 'DELETE FROM apps_routes WHERE app_id IN (SELECT id FROM apps WHERE app_guid IS NOT NULL);'
      run 'DELETE FROM apps WHERE app_guid IS NOT NULL;'
      self[:apps_v3_routes].truncate
      self[:apps_v3].truncate
      self[:v3_droplets].truncate
      self[:packages].truncate

      alter_table(:apps_v3_routes) do
        add_foreign_key :app_v3_id, :apps_v3
      end
      alter_table(:apps) do
        add_index :app_guid
        add_foreign_key [:app_guid], :apps_v3, key: :guid
      end
      alter_table(:packages) do
        add_foreign_key [:app_guid], :apps_v3, key: :guid
      end
      alter_table(:v3_droplets) do
        add_foreign_key [:app_guid], :apps_v3, key: :guid
      end

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

  down do
    drop_table :buildpack_lifecycle_data
  end
end
