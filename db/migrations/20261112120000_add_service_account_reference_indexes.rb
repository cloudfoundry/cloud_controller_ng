Sequel.migration do
  no_transaction

  up do
    {
      service_bindings: [:service_bindings_service_account_guid_index, [:service_account_guid]],
      processes: [:processes_service_account_guid_state_index, %i[service_account_guid state]],
      tasks: [:tasks_service_account_guid_state_index, %i[service_account_guid state]]
    }.each do |table, (name, columns)|
      next if indexes(table).key?(name)

      VCAP::Migration.with_concurrent_timeout(self) do
        add_index table, columns, name: name, concurrently: database_type == :postgres
      end
    end
  end

  down do
    {
      service_bindings: :service_bindings_service_account_guid_index,
      processes: :processes_service_account_guid_state_index,
      tasks: :tasks_service_account_guid_state_index
    }.each do |table, name|
      next unless indexes(table).key?(name)

      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index table, nil, name: name, concurrently: database_type == :postgres
      end
    end
  end
end
