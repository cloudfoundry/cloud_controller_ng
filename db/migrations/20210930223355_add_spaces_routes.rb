Sequel.migration do
  change do
    create_table :spaces_routes do
      Integer :space_id, null: false
      foreign_key [:space_id], :spaces, name: :fk_space_id

      Integer :route_id, null: false
      foreign_key [:route_id], :routes, name: :fk_route_id

      index [:space_id, :route_id], unique: true, name: 'space_route_ids'
    end
  end
end
