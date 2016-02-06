require 'cloud_controller/diego/buildpack/v3/buildpack_entry_generator'
require 'cloud_controller/diego/normal_env_hash_to_diego_env_array_philosopher'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/diego/buildpack/lifecycle_data'

module VCAP::CloudController
  module Diego
    module V3
      module Protocol
        class AppProtocol
          def initialize(lifecycle_protocol, egress_rules)
            @lifecycle_protocol = lifecycle_protocol
            @egress_rules       = egress_rules
          end

          def stage_package_request(package, config, staging_details)
            env = VCAP::CloudController::Diego::NormalEnvHashToDiegoEnvArrayPhilosopher.muse(staging_details.environment_variables)
            logger.debug2("staging environment: #{env.map { |e| e['name'] }}")

            lifecycle_type, lifecycle_data = @lifecycle_protocol.lifecycle_data(package, staging_details)

            staging_request                     = StagingRequest.new
            staging_request.app_id              = staging_details.droplet.guid
            staging_request.log_guid            = package.app_guid
            staging_request.environment         = env
            staging_request.memory_mb           = staging_details.memory_limit
            staging_request.disk_mb             = staging_details.disk_limit
            staging_request.file_descriptors    = config[:staging][:minimum_staging_file_descriptor_limit]
            staging_request.egress_rules        = @egress_rules.staging
            staging_request.timeout             = config[:staging][:timeout_in_seconds]
            staging_request.lifecycle           = lifecycle_type
            staging_request.lifecycle_data      = lifecycle_data
            staging_request.completion_callback = staging_completion_callback(staging_details.droplet, config)

            staging_request.message
          end

          private

          def staging_completion_callback(droplet, config)
            auth      = "#{config[:internal_api][:auth_user]}:#{config[:internal_api][:auth_password]}"
            host_port = "#{config[:internal_service_hostname]}:#{config[:external_port]}"
            path      = "/internal/v3/staging/#{droplet.guid}/droplet_completed"
            "http://#{auth}@#{host_port}#{path}"
          end

          def logger
            @logger ||= Steno.logger('cc.diego.tr')
          end
        end
      end
    end
  end
end
