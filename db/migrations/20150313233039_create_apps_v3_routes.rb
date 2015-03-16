Sequel.migration do
  change do
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
