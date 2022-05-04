Sequel.migration do
  change do
    create_table :route_shares do
      String :route_guid, null: false, size: 255
      String :target_space_guid, null: false, size: 255

      foreign_key [:route_guid], :routes, key: :guid, name: :fk_route_guid, on_delete: :cascade
      foreign_key [:target_space_guid], :spaces, key: :guid, name: :fk_target_space_guid_route_share, on_delete: :cascade
      primary_key [:route_guid, :target_space_guid], name: :route_target_space_pk
    end
  end
end
