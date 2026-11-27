Sequel.migration do
  no_transaction # required for concurrently option on postgres

  up do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :events, %i[type created_at id],
                  name: :events_type_created_at_id_index,
                  if_not_exists: true,
                  concurrently: true
      end
    else
      alter_table(:events) do
        # rubocop:disable Sequel/ConcurrentIndex
        unless @db.indexes(:events).key?(:events_type_created_at_id_index)
          add_index %i[type created_at id],
                    name: :events_type_created_at_id_index
        end
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :events, nil,
                   name: :events_type_created_at_id_index,
                   if_exists: true,
                   concurrently: true
      end
    else
      alter_table(:events) do
        # rubocop:disable Sequel/ConcurrentIndex
        drop_index nil, name: :events_type_created_at_id_index if @db.indexes(:events).key?(:events_type_created_at_id_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end
end
