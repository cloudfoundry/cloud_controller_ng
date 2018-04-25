Sequel.migration do
  change do
    create_table :deployments do
      VCAP::Migration.common(self)
      String :state, size: 255
      String :app_guid, size: 255
      index :app_guid, name: :deployments_app_guid_index
      foreign_key [:app_guid], :apps, key: :guid, name: :deployments_app_guid_fkey
    end
  end
end
