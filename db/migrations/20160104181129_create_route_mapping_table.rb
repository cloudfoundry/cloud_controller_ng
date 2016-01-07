Sequel.migration do
  up do
    create_table :route_mappings do
      VCAP::Migration.common(self)

      foreign_key :app_id, :apps
      foreign_key :route_id, :routes
      Integer :app_port
    end

    if self.class.name.match /mysql/i
      run 'insert into route_mappings (guid,  app_id, route_id) select UUID(),  app_id, route_id from apps_routes;'
    elsif self.class.name.match /postgres/i
      run 'insert into route_mappings (guid,  app_id, route_id) select gen_random_uuid(),  app_id, route_id from apps_routes;'
    end
  end

  down do
    drop_table(:route_mappings)
  end
end
