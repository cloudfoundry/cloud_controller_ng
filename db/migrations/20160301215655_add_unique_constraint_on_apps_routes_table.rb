Sequel.migration do
  up do
    # We are assuming with this DB migration that no apps_routes table currently
    # has duplicate rows, according to the unique constraint
    # of (app_id, route_id, app_port). This migration will fail otherwise.

    alter_table :apps_routes do
      add_unique_constraint [:app_id, :route_id, :app_port], :name=>:apps_routes_app_id_route_id_app_port_key
    end
  end

  down do
    alter_table :apps_routes do
      drop_constraint (:apps_routes_app_id_route_id_app_port_key)
    end
  end
end
