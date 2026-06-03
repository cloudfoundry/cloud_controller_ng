Sequel.migration do
  no_transaction # required for concurrently option on postgres

  up do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :jobs, %i[operation state],
                  name: :jobs_operation_state_index,
                  where: "state IN ('POLLING', 'FAILED')",
                  if_not_exists: true,
                  concurrently: true
      end
    elsif database_type == :mysql
      alter_table(:jobs) do
        # rubocop:disable Sequel/ConcurrentIndex -- MySQL does not support concurrent index operations
        add_index %i[operation state], name: :jobs_operation_state_index unless @db.indexes(:jobs).key?(:jobs_operation_state_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :jobs, %i[operation state],
                   name: :jobs_operation_state_index,
                   if_exists: true,
                   concurrently: true
      end
    elsif database_type == :mysql
      alter_table(:jobs) do
        # rubocop:disable Sequel/ConcurrentIndex
        drop_index %i[operation state], name: :jobs_operation_state_index if @db.indexes(:jobs).key?(:jobs_operation_state_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
