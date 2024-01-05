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

  no_transaction # Disable automatic transactions

  up do
    annotation_tables.each do |table|
      transaction do
        # PSQL renames columns in views automatically just mysql cannot do it
        drop_view(:"#{table}_migration_view", if_exists: true) if database_type == :mysql
        rename_column table.to_sym, :key, :key_name if schema(table.to_sym).map(&:first).include?(:key)
        if database_type == :mysql
          create_view(:"#{table}_migration_view", self[table.to_sym].select do
                                                    [id, guid, created_at, updated_at, resource_guid, key_prefix, key_name, value]
                                                  end)
        end
      end
    end
  end

  down do
    annotation_tables.each do |table|
      transaction do
        # PSQL renames columns in views automatically just mysql cannot do it
        drop_view(:"#{table}_migration_view", if_exists: true) if database_type == :mysql
        rename_column table.to_sym, :key_name, :key if schema(table.to_sym).map(&:first).include?(:key_name)
        if database_type == :mysql
          create_view(:"#{table}_migration_view", self[table.to_sym].select do
                                                    [id, guid, created_at, updated_at, resource_guid, key_prefix, key, value]
                                                  end)
        end
      end
    end
  end
end
