base_names = %w[
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
]
annotation_tables_to_migrate = base_names.map { |base_name| "#{base_name}_annotations" }
label_tables_to_migrate = base_names.map { |base_name| "#{base_name}_labels" }

Sequel.migration do
  up do
    annotation_tables_to_migrate.each do |table|
      transaction do
        # Adding a temporary column
        add_column table.to_sym, :temp_key, String, size: 63

        # Just allow selects on this table while the migration runs for full consistency
        if database_type == :postgres
          run "LOCK TABLE #{table} IN SHARE MODE;"
        elsif database_type == :mysql
          run "LOCK TABLES #{table} WRITE;"
        end

        # Updating the temporary column with truncated keys(should never chop of anything since the api just allows 63 chars)
        # We run this in the DB as to miminize the time we hold the share mode lock on the table
        self[table.to_sym].update(temp_key: Sequel::SQL::Function.new(:SUBSTR, :key, 1, 63))

        # Removing the original 'key' column
        drop_column table.to_sym, :key

        # Renaming the temporary column back to 'key'
        rename_column table.to_sym, :temp_key, :key

        # Delete duplicates (also in the DB as to miminize the time we hold the share mode lock on the table)
        create_table(:tmp_table, temp: true, as: self[table.to_sym].
          select(:resource_guid, :key_prefix, :key, Sequel.function(:MIN, :id).as(:min_id)).
          group(:resource_guid, :key_prefix, :key).
          having { count(Sequel.lit('*')) > 1 })
        self[table.to_sym].join(:tmp_table) do |j, lj|
          {
            Sequel[lj][:resource_guid] => Sequel[j][:resource_guid],
            Sequel[lj][:key] => Sequel[j][:key],
            Sequel.|(Sequel.&(Sequel[lj][:key_prefix] => Sequel[j][:key_prefix]),
                     Sequel.&(Sequel[lj][:key_prefix] => nil, Sequel[j][:key_prefix] => nil)) => true
          }
        end.filter(Sequel[table.to_sym][:id] => Sequel[:tmp_table][:min_id]).delete
        drop_table(:tmp_table)

        # Add unique constraint
        alter_table(table.to_sym) do
          add_unique_constraint [:resource_guid, :key_prefix, :key], name: :unique_resource_guid_key_prefix_key
        end

        # Be sure to unlock the table afterwards as this does not happen automatically after committing a transaction
        run 'UNLOCK TABLES;' if database_type == :mysql
      rescue Sequel::DatabaseError
        # In any case unlock the tables for mysql, opposed to psql in mysql tables are not automatically unlocked in case of transaction rollbacks or errors
        run 'UNLOCK TABLES;' if database_type == :mysql
      end
    end

    label_tables_to_migrate.each do |table|
      transaction do
        # Just allow selects on this table while the migration runs for full consistency
        if database_type == :postgres
          run "LOCK TABLE #{table} IN SHARE MODE;"
        elsif database_type == :mysql
          run "LOCK TABLES #{table} WRITE;"
        end

        # Delete duplicates (in the DB as doing it in ruby is slow)
        create_table(:tmp_table, temp: true, as: self[table.to_sym].
          select(:resource_guid, :key_prefix, :key_name, Sequel.function(:MIN, :id).as(:min_id)).
          group(:resource_guid, :key_prefix, :key_name).
          having { count(Sequel.lit('*')) > 1 })
        self[table.to_sym].join(:tmp_table) do |j, lj|
          {
            Sequel[lj][:resource_guid] => Sequel[j][:resource_guid],
            Sequel[lj][:key_name] => Sequel[j][:key_name],
            Sequel.|(Sequel.&(Sequel[lj][:key_prefix] => Sequel[j][:key_prefix]),
                     Sequel.&(Sequel[lj][:key_prefix] => nil, Sequel[j][:key_prefix] => nil)) => true
          }
        end.filter(Sequel[table.to_sym][:id] => Sequel[:tmp_table][:min_id]).delete
        drop_table(:tmp_table)

        # Add unique constraint (drop for idempotency)
        alter_table(table.to_sym) do
          add_unique_constraint [:resource_guid, :key_prefix, :key_name], name: :unique_resource_guid_key_prefix_key_name
        end
        # Be sure to unlock the table afterwards as this does not happen automatically after committing a transaction
        run 'UNLOCK TABLES;' if database_type == :mysql
      rescue Sequel::DatabaseError
        # In any case unlock the tables for mysql, opposed to psql in mysql tables are not automatically unlocked in case of transaction rollbacks or errors
        run 'UNLOCK TABLES;' if database_type == :mysql
      end
    end
  end

  down do
    annotation_tables_to_migrate.each do |table|
      # Drop unique constraint
      transaction do
        drop_index table.to_sym, nil, name: :unique_resource_guid_key_prefix_key
      rescue Sequel::DatabaseError
        # Ignore failures
      end
    end
    label_tables_to_migrate.each do |table|
      # Drop unique constraint
      transaction do
        drop_index table.to_sym, nil, name: :unique_resource_guid_key_prefix_key_name
      rescue Sequel::DatabaseError
        # Ignore failures
      end
    end
  end
end
