require 'cloud_controller/diego/environment'
require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  module Diego
    module Docker
      class Protocol
        def initialize(common_protocol)
          @common_protocol = common_protocol
        end

        def stage_app_request(app, staging_timeout)
          ['diego.docker.staging.start', stage_app_message(app, staging_timeout).to_json]
        end

        def stage_app_message(app, staging_timeout)
          {
            'app_id' => app.guid,
            'task_id' => app.staging_task_id,
            'memory_mb' => app.memory,
            'disk_mb' => app.disk_quota,
            'file_descriptors' => app.file_descriptors,
            'stack' => app.stack.name,
            'docker_image' => app.docker_image,
            'egress_rules' => @common_protocol.staging_egress_rules,
            'timeout' => staging_timeout,
          }
        end

        def desire_app_request(app)
          ['diego.docker.desire.app', desire_app_message(app).to_json]
        end

        def stop_staging_app_request(app, task_id)
          ['diego.docker.staging.stop', stop_staging_message(app, task_id).to_json]
        end

        def desire_app_message(app)
          message = {
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
            'docker_image' => app.docker_image,
            'health_check_type' => app.health_check_type,
            'egress_rules' => @common_protocol.running_egress_rules(app),
            'etag' => app.updated_at.to_f.to_s
          }

          message['health_check_timeout_in_seconds'] = app.health_check_timeout if app.health_check_timeout

          message
        end

        def stop_staging_message(app, task_id)
          {
            'app_id' => app.guid,
            'task_id' => task_id,
          }
        end

        def stop_index_request(app, index)
          @common_protocol.stop_index_request(app, index)
        end
      end
    end
  end
end
