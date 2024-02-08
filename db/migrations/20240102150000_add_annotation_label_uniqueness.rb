require 'logger'

def unique_index_name(table)
  :"#{table}_unique"
end

def with_dropped_view(table)
  # Recreate view just for postgres as it cannot alter types while a view is on the table
  if database_type == :postgres
    drop_view(:"#{table}_migration_view", if_exists: true)
    yield if block_given?
    create_view(:"#{table}_migration_view", self[table.to_sym].select do
      [id, guid, created_at, updated_at, resource_guid, key_prefix, key_name, value]
    end)
  elsif block_given?
    yield
  end
end

Sequel.migration do
  table_base_names = %w[
    app
    build
    buildpack
    deployment
    domain
    droplet
    isolation_segment
    organization
    package
    process
    revision
    route_binding
    route
    service_binding
    service_broker
    service_broker_update_request
    service_instance
    service_key
    service_offering
    service_plan
    space
    stack
    task
    user
  ].freeze
  annotation_tables = table_base_names.map { |tbn| "#{tbn}_annotations" }.freeze
  label_tables = table_base_names.map { |tbn| "#{tbn}_labels" }.freeze

  no_transaction # Disable automatic transactions
  db_supports_table_locks = true

  up do
    (annotation_tables + label_tables).each do |table|
      transaction do
        run 'SET work_mem = 65536;' if database_type == :postgres

        # Create Temporary table for use later on
        create_table! :"#{table}_temp", temp: true do
          primary_key :id, name: :id
          Integer :min_id, null: false
        end

        # Just allow selects on this table while the migration runs for full consistency
        run "LOCK TABLE #{table}, #{table}_temp IN SHARE MODE;" if database_type == :postgres
        begin
          run "LOCK TABLES #{table} WRITE, #{table}_temp WRITE;" if database_type == :mysql && db_supports_table_locks
        rescue Sequel::DatabaseError
          db_supports_table_locks = false
          # rubocop:disable Layout/LineLength, Rails/Output
          p("Cannot guarantee consistent migration for table #{table} as your used user lacks the \"LOCK TABLE\" Permission or the database does not support locking tables (e.g. percona xtradb cluster).")
          p("Continuing to do the migration for table #{table}, there is a small chance of a migration failure due to lack of above feature but eventually reruns of this migration should succeed.")
          # rubocop:enable Layout/LineLength, Rails/Output
        end

        # Updating the temporary column with truncated keys(should never chop of anything since the api just allows 63 chars)
        # We run this in the DB as to minimize the time we hold the share mode lock on the table
        self[table.to_sym].update(key_name: Sequel::SQL::Function.new(:SUBSTR, :key_name, 1, 63))

        # Make en empty string the default for key_prefix as null in the unique constraint would not work.
        # Null values are not equal to other Null values so a row that has NULL can be a duplicate then.
        self[table.to_sym].where(key_prefix: nil).update(key_prefix: '')
        self[table.to_sym].where(key_name: nil).update(key_name: '')

        # Recreate view just for postgres as it cannot alter types while a view is on the table
        with_dropped_view(table) do
          alter_table(table.to_sym) do
            set_column_default :key_prefix, ''
            set_column_not_null :key_prefix
            set_column_not_null :key_name
            set_column_type :key_name, String, size: 63
          end
        end

        # Delete duplicates (in the DB as doing it in ruby is slow), we need to use a temporary table
        # as mysql doesnt allow subselects on the same table it deletes from
        min_ids = from(table.to_sym).
                  select(Sequel.function(:MIN, :id).as(:min_id)).
                  group_by(:resource_guid, :key_prefix, :key_name)
        self[:"#{table}_temp"].import([:min_id], min_ids)
        self[table.to_sym].exclude(id: from(:"#{table}_temp").select(:min_id)).delete

        # Add unique constraint if not already present
        if indexes(table.to_sym)[unique_index_name(table)].nil?
          alter_table(table.to_sym) do
            add_unique_constraint %i[resource_guid key_prefix key_name], name: unique_index_name(table)
          end
        end
      ensure
        # Be sure to unlock the table on errors as this does not happen automatically by rolling back a transaction mysql
        run 'UNLOCK TABLES;' if database_type == :mysql && db_supports_table_locks
      end
    end
  end

  down do
    (annotation_tables + label_tables).each do |table|
      transaction do
        # Drop unique constraint
        if indexes(table.to_sym)[unique_index_name(table)].present?
          alter_table(table.to_sym) do
            drop_constraint(unique_index_name(table), type: :unique)
          end
        end
        # Revert default type in key_prefix and null values handling
        with_dropped_view(table) do
          alter_table(table.to_sym) do
            set_column_allow_null :key_prefix
            set_column_allow_null :key_name
            set_column_default :key_prefix, nil
            set_column_type :key_name, String, size: 1000 if table.end_with?('_annotations')
          end
        end
      end
    end
  end
end
