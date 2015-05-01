require 'cloud_controller/diego/environment'
require 'cloud_controller/diego/process_guid'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/diego/docker/lifecycle_data'

module VCAP::CloudController
  module Diego
    module Docker
      class Protocol
        def initialize(common_protocol)
          @common_protocol = common_protocol
        end

        def stage_app_request(app, staging_config)
          stage_app_message(app, staging_config).to_json
        end

        def stage_app_message(app, staging_config)
          lifecycle_data = LifecycleData.new
          lifecycle_data.docker_image = app.docker_image

          staging_request = StagingRequest.new
          staging_request.app_id = app.guid
          staging_request.log_guid = app.guid
          staging_request.environment = Environment.new(app).as_json
          staging_request.memory_mb = [app.memory, staging_config[:minimum_staging_memory_mb]].max
          staging_request.disk_mb = [app.disk_quota, staging_config[:minimum_staging_disk_mb]].max
          staging_request.file_descriptors = [app.file_descriptors, staging_config[:minimum_staging_file_descriptor_limit]].max
          staging_request.egress_rules = @common_protocol.staging_egress_rules
          staging_request.timeout = staging_config[:timeout_in_seconds]
          staging_request.lifecycle = 'docker'
          staging_request.lifecycle_data = lifecycle_data.message

          staging_request.message
        end

        def desire_app_request(app, default_health_check_timeout)
          desire_app_message(app, default_health_check_timeout).to_json
        end

        def desire_app_message(app, default_health_check_timeout)
          cached_docker_image = app.current_droplet.cached_docker_image if app.current_droplet

          {
            'process_guid' => ProcessGuid.from_app(app),
            'memory_mb' => app.memory,
            'disk_mb' => app.disk_quota,
            'file_descriptors' => app.file_descriptors,
            'stack' => app.stack.name,
            'start_command' => app.command,
            'execution_metadata' => app.execution_metadata,
            'environment' => Environment.new(app).as_json,
            'num_instances' => app.desired_instances,
            'routes' => app.uris,
            'log_guid' => app.guid,
            'docker_image' => cached_docker_image || app.docker_image,
            'health_check_type' => app.health_check_type,
            'health_check_timeout_in_seconds' => app.health_check_timeout || default_health_check_timeout,
            'egress_rules' => @common_protocol.running_egress_rules(app),
            'etag' => app.updated_at.to_f.to_s,
            'allow_ssh' => app.enable_ssh,
          }
        end
      end
    end
  end
end
