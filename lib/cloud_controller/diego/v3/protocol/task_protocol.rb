require 'cloud_controller/diego/buildpack/v3/buildpack_entry_generator'
require 'cloud_controller/diego/environment'
require 'cloud_controller/diego/staging_request'
require 'cloud_controller/diego/buildpack/lifecycle_data'

module VCAP::CloudController
  module Diego
    module V3
      module Protocol
        class TaskProtocol
          def initialize(egress_rules)
            @egress_rules = egress_rules
          end

          def task_request(task, config)
            if task.droplet.environment_variables
              env = VCAP::CloudController::Diego::Environment.hash_to_diego_env(task.droplet.environment_variables)
            end

            blobstore_url_generator = CloudController::DependencyLocator.instance.blobstore_url_generator(true)

            result = {
              log_guid:              task.app.guid,
              memory_mb:             config[:default_app_memory],
              disk_mb:               config[:default_app_disk_in_mb],
              environment_variables: env || nil,
              egress_rules:          @egress_rules.running(task.app),
              droplet_url:           blobstore_url_generator.v3_droplet_download_url(task.droplet),
              completion_callback:   task_completion_callback(task, config),
              lifecycle_type:        task.app.lifecycle_type,
              command:               task.command,
            }

            if task.app.lifecycle_type == Lifecycles::BUILDPACK
              result = result.merge({
                rootfs: task.app.lifecycle_data.stack,
              })
            elsif task.app.lifecycle_type == Lifecycles::DOCKER
              result = result.merge(
                rootfs: task.droplet.docker_receipt_image,
              )
            end

            result
          end

          private

          def task_completion_callback(task, config)
            auth      = "#{config[:internal_api][:auth_user]}:#{config[:internal_api][:auth_password]}"
            host_port = "#{config[:internal_service_hostname]}:#{config[:external_port]}"
            path      = "/internal/v3/task/#{task.guid}/completed"
            "http://#{auth}@#{host_port}#{path}"
          end
        end
      end
    end
  end
end
