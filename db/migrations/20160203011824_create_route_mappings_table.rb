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
      if Sequel::Model.db.database_type != :mssql
        unique [:app_guid, :route_guid, :process_type]
      else
        add_unique_constraint [:app_guid, :route_guid, :process_type], name: 'route_mappings_app_guid_route_guid_process_type_key'
      end
    end
  end
end
