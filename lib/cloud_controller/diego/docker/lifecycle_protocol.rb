require 'cloud_controller/diego/docker/lifecycle_data'

module VCAP
  module CloudController
    module Diego
      module Docker
        class LifecycleProtocol
          def lifecycle_data(staging_details)
            lifecycle_data              = Diego::Docker::LifecycleData.new
            lifecycle_data.docker_image = staging_details.package.image
            lifecycle_data.message
          end

          def desired_app_message(process)
            {
              'start_command' => process.command,
              'docker_image'  => process.current_droplet.docker_receipt_image
            }
          end
        end
      end
    end
  end
end
