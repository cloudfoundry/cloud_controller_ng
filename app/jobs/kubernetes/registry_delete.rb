module VCAP::CloudController
  module Jobs
    module Kubernetes
      class RegistryDelete < VCAP::CloudController::Jobs::CCJob
        def initialize(image_reference)
          @image_reference = image_reference
        end

        attr_reader :image_reference

        def perform
          client = CloudController::DependencyLocator.instance.registry_buddy_client
          client.delete_image(image_reference)
        end

        def max_attempts
          3
        end
      end
    end
  end
end
