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

  up do
    (annotation_tables + label_tables).each do |table|
      transaction do
        drop_view(:"#{table}_migration_view", if_exists: true)
      end
    end
  end

  down do
    (annotation_tables + label_tables).each do |table|
      transaction do
        create_view(:"#{table}_migration_view", self[table.to_sym].select { [id, guid, created_at, updated_at, resource_guid, key_prefix, key_name, value] }, if_exists: true)
      end
    end
  end
end
