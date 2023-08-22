TABLE_BASE_NAMES = %w[
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
annotation_tables = TABLE_BASE_NAMES.map { |tbn| "#{tbn}_annotations" }.freeze

Sequel.migration do
  up do
    annotation_tables.each do |table|
      create_view("#{table}_migration_view".to_sym, self[table.to_sym].select { [id, guid, created_at, updated_at, resource_guid, key_prefix, key.as(key_name), value] })
    end
  end
  down do
    annotation_tables.each do |table|
      drop_view("#{table}_migration_view".to_sym, if_exists: true)
    end
  end
end
