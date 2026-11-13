Sequel.migration do
  no_transaction

  up do
    {
      service_bindings: [:service_bindings_service_account_guid_index, [:service_account_guid]],
      processes: [:processes_service_account_guid_state_index, %i[service_account_guid state]],
      tasks: [:tasks_service_account_guid_state_index, %i[service_account_guid state]]
    }.each do |table, (name, columns)|
      VCAP::Migration.with_concurrent_timeout(self) do
        if database_type == :postgres
          index_valid = fetch('SELECT indisvalid FROM pg_index WHERE indexrelid = to_regclass(?)', name.to_s).get(:indisvalid)
          drop_index table, columns, name: name, concurrently: true if index_valid == false
          add_index table, columns, name: name, concurrently: true unless index_valid
        elsif !indexes(table).key?(name)
          add_index table, columns, name: name, concurrently: false
        end
      end
    end
  end

  down do
    {
      service_bindings: :service_bindings_service_account_guid_index,
      processes: :processes_service_account_guid_state_index,
      tasks: :tasks_service_account_guid_state_index
    }.each do |table, name|
      VCAP::Migration.with_concurrent_timeout(self) do
        if database_type == :postgres
          drop_index table, nil, name: name, concurrently: true, if_exists: true
        elsif indexes(table).key?(name)
          drop_index table, nil, name: name, concurrently: false
        end
      end
    end
  end
end
