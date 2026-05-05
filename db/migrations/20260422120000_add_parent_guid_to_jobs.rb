Sequel.migration do
  no_transaction

  up do
    if database_type == :postgres
      add_column :jobs, :parent_guid, String, size: 255, if_not_exists: true
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index :jobs, :parent_guid, name: :jobs_parent_guid_index, if_not_exists: true, concurrently: true
      end

    elsif database_type == :mysql
      alter_table :jobs do
        add_column :parent_guid, String, size: 255 unless @db.schema(:jobs).map(&:first).include?(:parent_guid)
        # rubocop:disable Sequel/ConcurrentIndex
        add_index :parent_guid, name: :jobs_parent_guid_index unless @db.indexes(:jobs).include?(:jobs_parent_guid_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :jobs, :parent_guid, name: :jobs_parent_guid_index, if_exists: true, concurrently: true
      end
      drop_column :jobs, :parent_guid, if_exists: true
    end

    if database_type == :mysql
      alter_table :jobs do
        # rubocop:disable Sequel/ConcurrentIndex
        drop_index :parent_guid, name: :jobs_parent_guid_index if @db.indexes(:jobs).include?(:jobs_parent_guid_index)
        # rubocop:enable Sequel/ConcurrentIndex
        drop_column :parent_guid if @db.schema(:jobs).map(&:first).include?(:parent_guid)
      end
    end
  end
end
