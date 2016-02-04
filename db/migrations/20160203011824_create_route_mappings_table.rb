Sequel.migration do
  up do
    drop_table(:apps_v3_routes)

    create_table :route_mappings do
      VCAP::Migration.common(self, :route_mappings)

      foreign_key :app_v3_id, :apps_v3
      foreign_key :route_id, :routes

      String :process_type
      index :process_type
    end
  end
end
