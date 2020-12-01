require 'vcap/config'
require 'cloud_controller/config_schemas/base/migrate_schema'

module VCAP::CloudController
  module ConfigSchemas
    module Kubernetes
      MigrateSchema = VCAP::CloudController::ConfigSchemas::Base::MigrateSchema
    end
  end
end
