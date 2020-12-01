require 'vcap/config'
require 'cloud_controller/resource_pool'
require 'cloud_controller/config_schemas/base/api_schema'

module VCAP::CloudController
  module ConfigSchemas
    module Vms
      class ApiSchema < VCAP::Config
        self.parent_schema = VCAP::CloudController::ConfigSchemas::Base::ApiSchema

        define_schema do
          {
            staging: {
              auth: {
                user: String,
                password: String,
              },
            },

            diego: {
              bbs: {
                url: String,
                ca_file: String,
                cert_file: String,
                key_file: String,
                connect_timeout: Integer,
                send_timeout: Integer,
                receive_timeout: Integer,
              },
              cc_uploader_url: String,
              file_server_url: String,
              lifecycle_bundles: Hash,
              droplet_destinations: Hash,
              pid_limit: Integer,
              use_privileged_containers_for_running: bool,
              use_privileged_containers_for_staging: bool,
              insecure_docker_registry_list: [String],
              docker_staging_stack: String,
              optional(:temporary_oci_buildpack_mode) => enum('oci-phase-1', NilClass),
              enable_declarative_asset_downloads: bool,
            },

            internal_api: {
              auth_user: String,
              auth_password: String,
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
