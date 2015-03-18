Sequel.migration do
  up do
    drop_table :apps_v3_routes
    create_table :apps_v3_routes do
      primary_key :id
      foreign_key :app_v3_id, :apps_v3
      foreign_key :route_id, :routes

      String :type
      index :type
    end
  end

  down do
    drop_table :apps_v3_routes
    create_table :apps_v3_routes do
      Integer :apps_v3_id
      index :apps_v3_id, name: :apps_routes_apps_id_v3

      Integer :route_id
      index :route_id

      String :type
      index :type
    end
  end
end
