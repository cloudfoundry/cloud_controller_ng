Sequel.migration do
  roles_tables = %w[
    organizations_auditors
    organizations_billing_managers
    organizations_managers
    organizations_users
    spaces_auditors
    spaces_developers
    spaces_managers
    spaces_supporters
  ]

  # adding an index concurrently cannot be done within a transaction
  no_transaction

  up do
    roles_tables.each do |table|
      # MySQL already has an index on user_id (foreign key constraint)
      next unless database_type == :postgres

      table_sym = table.to_sym
      index_sym = :"#{table}_user_id_index"
      VCAP::Migration.with_concurrent_timeout(self) do
        add_index table_sym, :user_id, name: index_sym, if_not_exists: true, concurrently: true
      end
    end
  end

  down do
    roles_tables.each do |table|
      next unless database_type == :postgres

      table_sym = table.to_sym
      index_sym = :"#{table}_user_id_index"
      VCAP::Migration.with_concurrent_timeout(self) do
        drop_index table_sym, :user_id, name: index_sym, if_exists: true, concurrently: true
      end
    end
  end
end
