Sequel.migration do
  # adding an index concurrently cannot be done within a transaction
  no_transaction

  up do
    if database_type == :postgres
      alter_table :jobs do
        add_column :user_guid, String, size: 255, if_not_exists: true
        add_index :user_guid, name: :jobs_user_guid_index, if_not_exists: true, concurrently: true
      end

    elsif database_type == :mysql
      alter_table :jobs do
        add_column :user_guid, String, size: 255 unless @db.schema(:jobs).map(&:first).include?(:user_guid)
        # rubocop:disable Sequel/ConcurrentIndex
        add_index :user_guid, name: :jobs_user_guid_index unless @db.indexes(:jobs).include?(:jobs_user_guid_index)
        # rubocop:enable Sequel/ConcurrentIndex
      end
    end
  end

  down do
    if database_type == :postgres
      alter_table :jobs do
        drop_index  :user_guid, name: :jobs_user_guid_index, if_exists: true, concurrently: true
        drop_column :user_guid, if_exists: true
      end
    end

    if database_type == :mysql
      alter_table :jobs do
        # rubocop:disable Sequel/ConcurrentIndex
        drop_index  :user_guid, name: :jobs_user_guid_index if @db.indexes(:jobs).include?(:jobs_user_guid_index)
        # rubocop:enable Sequel/ConcurrentIndex
        drop_column :user_guid if @db.schema(:jobs).map(&:first).include?(:user_guid)
      end
    end
  end
end
