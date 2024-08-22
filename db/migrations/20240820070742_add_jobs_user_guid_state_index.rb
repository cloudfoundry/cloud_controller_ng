Sequel.migration do
  # adding an index concurrently cannot be done within a transaction
  no_transaction

  up do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :jobs, :user_guid, name: :jobs_user_guid_index, if_exists: true, concurrently: true
        add_index :jobs, %i[user_guid state], name: :jobs_user_guid_state_index, where: "state IN ('PROCESSING', 'POLLING')", if_not_exists: true, concurrently: true
      end
    end
  end

  down do
    if database_type == :postgres
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index :jobs, %i[user_guid state], name: :jobs_user_guid_state_index, if_exists: true, concurrently: true
        add_index :jobs, :user_guid, name: :jobs_user_guid_index, if_not_exists: true, concurrently: true
      end
    end
  end
end
