require 'cloud_controller/diego/docker/lifecycle_data'
require 'cloud_controller/diego/docker/staging_action_builder'
require 'cloud_controller/diego/docker/task_action_builder'
require 'cloud_controller/diego/windows_environment_sage'

module VCAP
  module CloudController
    module Diego
      module Docker
        class LifecycleProtocol
          ROOT_USERS = %w[root 0].freeze

          def lifecycle_data(staging_details)
            lifecycle_data              = Diego::Docker::LifecycleData.new
            lifecycle_data.docker_image = staging_details.package.image
            lifecycle_data.docker_user = staging_details.package.docker_username
            lifecycle_data.docker_password = staging_details.package.docker_password

            lifecycle_data.message
          end

          def staging_action_builder(config, staging_details)
            StagingActionBuilder.new(config, staging_details)
          end

          def task_action_builder(config, task)
            if task.docker? && !docker_run_action_user_permitted?(task.run_action_user)
              raise ::CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'Attempting to run task as root user, which is not permitted.')
            end

            TaskActionBuilder.new(config, task, { droplet_path: task.droplet.docker_receipt_image })
          end

          def desired_lrp_builder(config, process)
            if process.docker? && !docker_run_action_user_permitted?(process.run_action_user)
              raise ::CloudController::Errors::ApiError.new_from_details('UnprocessableEntity', 'Attempting to run process as root user, which is not permitted.')
            end

            DesiredLrpBuilder.new(config, builder_opts(process))
          end

          private

          def builder_opts(process)
            {
              ports: process.open_ports,
              docker_image: process.actual_droplet.docker_receipt_image,
              execution_metadata: process.execution_metadata,
              start_command: process.command,
              action_user: process.run_action_user,
              additional_container_env_vars: container_env_vars_for_process(process)
            }
          end

          def container_env_vars_for_process(process)
            additional_env = []
            additional_env + WindowsEnvironmentSage.ponder(process.app)
          end

          def docker_run_action_user_permitted?(run_action_user)
            Config.config.get(:allow_docker_root_user) || ROOT_USERS.exclude?(run_action_user)
          end
        end
      end
    end
  end
end
