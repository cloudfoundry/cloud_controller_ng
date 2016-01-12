Sequel.migration do
  up do
    if self.class.name.match /mysql/i
      run 'CREATE TRIGGER apps_routes_add_route_mapping
              AFTER INSERT ON apps_routes
              FOR EACH ROW
                 INSERT INTO route_mappings (guid,  app_id, route_id) VALUES(UUID(),NEW.app_id, NEW.route_id);'
      run 'CREATE TRIGGER apps_routes_delete_route_mapping
              AFTER DELETE ON apps_routes
              FOR EACH ROW
                 DELETE FROM route_mappings where app_id = OLD.app_id and route_id = OLD.route_id;'
    elsif self.class.name.match /postgres/i
      run 'CREATE OR REPLACE FUNCTION add_route_mapping() returns TRIGGER AS
              $BODY$
              BEGIN
                  INSERT INTO route_mappings (guid,  app_id, route_id) VALUES(gen_random_uuid(), NEW.app_id, NEW.route_id);
                  RETURN new;
              END;
              $BODY$
              language plpgsql;'
      run 'CREATE TRIGGER apps_routes_add_route_mapping
              AFTER INSERT ON apps_routes
              FOR EACH ROW
                 EXECUTE PROCEDURE add_route_mapping();'
      run 'CREATE OR REPLACE FUNCTION delete_route_mapping() returns TRIGGER AS
              $BODY$
              BEGIN
                  DELETE FROM route_mappings where app_id = OLD.app_id and route_id = OLD.route_id;
                  RETURN old;
              END;
              $BODY$
              language plpgsql;'
      run 'CREATE TRIGGER apps_routes_delete_route_mapping
              AFTER DELETE ON apps_routes
              FOR EACH ROW
                 EXECUTE PROCEDURE delete_route_mapping();'
    end
  end

  down do
    if self.class.name.match /mysql/i
      run 'DROP TRIGGER apps_routes_add_route_mapping;'
      run 'DROP TRIGGER apps_routes_delete_route_mapping;'
    elsif self.class.name.match /postgres/i
      run 'DROP TRIGGER apps_routes_add_route_mapping on apps_routes;'
      run 'DROP TRIGGER apps_routes_delete_route_mapping on apps_routes;'
      run 'DROP FUNCTION add_route_mapping();'
      run 'DROP FUNCTION delete_route_mapping();'
    end
  end
end
