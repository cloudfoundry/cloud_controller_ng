require 'cloud_controller/diego/docker/lifecycle_data'
require 'cloud_controller/diego/lifecycles/docker_lifecycle'

module VCAP
  module CloudController
    module Diego
      module Docker
        module V3
          class LifecycleProtocol
            def lifecycle_data(package, staging_details)
              lifecycle_data              = LifecycleData.new
              lifecycle_data.docker_image = package.docker_data.image
              # docker_credentials          = app.docker_credentials_json
              # if docker_credentials
              #   lifecycle_data.docker_login_server = docker_credentials['docker_login_server']
              #   lifecycle_data.docker_user         = docker_credentials['docker_user']
              #   lifecycle_data.docker_password     = docker_credentials['docker_password']
              #   lifecycle_data.docker_email        = docker_credentials['docker_email']
              # end
              ['docker', lifecycle_data.message]
            end
          end
        end
      end
    end
  end
end
