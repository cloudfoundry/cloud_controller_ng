require 'vcap/config'
require 'cloud_controller/config_schemas/migrate_schema'

module VCAP::CloudController
  module ConfigSchemas
    module Vms
      MigrateSchema = VCAP::CloudController::ConfigSchemas::MigrateSchema
    end
  end
end
