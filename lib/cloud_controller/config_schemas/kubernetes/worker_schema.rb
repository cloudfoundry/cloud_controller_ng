require 'vcap/config'
require 'cloud_controller/config_schemas/base/worker_schema'

module VCAP::CloudController
  module ConfigSchemas
    module Kubernetes
      class WorkerSchema < VCAP::Config
        self.parent_schema = VCAP::CloudController::ConfigSchemas::Base::WorkerSchema

        define_schema do
          {
            kubernetes: {
              host_url: String,
              service_account: {
                token_file: String,
              },
              ca_file: String,
              workloads_namespace: String,
              kpack: {
                builder_namespace: String,
                registry_service_account_name: String,
                registry_tag_base: String,
              }
            },
          }
        end

        class << self
          delegate :configure_components, to: :parent_schema
        end
      end
    end
  end
end
