require 'cloud_controller/diego/docker/lifecycle_data'
require 'cloud_controller/diego/lifecycles/docker_lifecycle'

module VCAP
  module CloudController
    module Diego
      module Docker
        module V3
          class LifecycleProtocol
            def lifecycle_data(package, _)
              lifecycle_data              = LifecycleData.new
              lifecycle_data.docker_image = package.docker_data.image
              [Lifecycles::DOCKER, lifecycle_data.message]
            end
          end
        end
      end
    end
  end
end
