Sequel.migration do
  up do
    add_index :routes, :space_id, name: :routes_space_id_index, options: %i[if_not_exists concurrently] if database_type == :postgres
  end

  down do
    drop_index :routes, :space_id, name: :routes_space_id_index, options: %i[if_exists concurrently] if database_type == :postgres
  end
end
