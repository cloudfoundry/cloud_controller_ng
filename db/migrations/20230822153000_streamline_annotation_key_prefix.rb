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
      # Output all annotations with a forward Slash
      annotations = self[table.to_sym].where(Sequel.like(:key, '%/%'))
      annotations.each do |annotation|
        prefix, key_name = VCAP::CloudController::MetadataHelpers.extract_prefix(annotation[:key].to_s)
        if prefix.present?
          self[table.to_sym].where(guid: annotation[:guid]).delete
          self[table.to_sym].insert(guid: annotation[:guid],
                                    created_at: annotation[:created_at],
                                    updated_at: Sequel::CURRENT_TIMESTAMP,
                                    resource_guid: annotation[:resource_guid],
                                    key_prefix: prefix,
                                    key: key_name,
                                    value: annotation[:value])
        end
      end
    end
  end
end
