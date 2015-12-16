Sequel.migration do
  change do
    create_table :route_mappings do
      VCAP::Migration.common(self)

      foreign_key :app_id, :apps
      foreign_key :route_id, :routes
    end
    add_column :route_mappings, :app_port, Integer
  end
end
