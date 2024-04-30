Sequel.migration do
  no_transaction # to use the 'concurrently' option

  up do
    VCAP::Migration.with_concurrent_timeout(self) do
      add_index :routes, :space_id, name: :routes_space_id_index, if_not_exists: true, concurrently: true if database_type == :postgres
    end
  end

  down do
    VCAP::Migration.with_concurrent_timeout(self) do
      drop_index :routes, :space_id, name: :routes_space_id_index, if_exists: true, concurrently: true if database_type == :postgres
    end
  end
end
