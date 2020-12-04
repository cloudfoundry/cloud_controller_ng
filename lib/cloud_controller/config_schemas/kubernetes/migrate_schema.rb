require 'vcap/config'
require 'cloud_controller/config_schemas/migrate_schema'

module VCAP::CloudController
  module ConfigSchemas
    module Kubernetes
      MigrateSchema = VCAP::CloudController::ConfigSchemas::MigrateSchema
    end
  end
end
