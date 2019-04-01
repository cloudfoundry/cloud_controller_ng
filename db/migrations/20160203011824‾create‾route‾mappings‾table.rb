Sequel.migration do
  up do
    drop_table(:apps_v3_routes)

    create_table :route_mappings do
      VCAP::Migration.common(self, :route_mappings)

      String :app_guid
      index :app_guid
      foreign_key [:app_guid], :apps_v3, key: :guid

      String :route_guid
      index :route_guid
      foreign_key [:route_guid], :routes, key: :guid

      String :process_type
      index :process_type

      unique [:app_guid, :route_guid, :process_type]
    end
  end
end
