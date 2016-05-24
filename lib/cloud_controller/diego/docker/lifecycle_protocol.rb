require 'cloud_controller/diego/docker/lifecycle_data'

module VCAP
  module CloudController
    module Diego
      module Docker
        class LifecycleProtocol
          def lifecycle_data(process)
            lifecycle_data = LifecycleData.new
            lifecycle_data.docker_image = process.docker_image
            docker_credentials = process.docker_credentials_json
            if docker_credentials
              lifecycle_data.docker_login_server = docker_credentials['docker_login_server']
              lifecycle_data.docker_user = docker_credentials['docker_user']
              lifecycle_data.docker_password = docker_credentials['docker_password']
              lifecycle_data.docker_email = docker_credentials['docker_email']
            end
            [Lifecycles::DOCKER, lifecycle_data.message]
          end

          def desired_app_message(process)
            cached_docker_image = process.current_droplet.cached_docker_image if process.current_droplet

            {
              'start_command' => process.command,
              'docker_image'  => cached_docker_image || process.docker_image,
            }
          end
        end
      end
    end
  end
end
