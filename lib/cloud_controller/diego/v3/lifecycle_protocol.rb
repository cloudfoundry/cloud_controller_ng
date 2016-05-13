module VCAP::CloudController
  module Diego
    module V3
      module LifecycleProtocol
        def self.protocol_for_type(lifecycle_type)
          if lifecycle_type == VCAP::CloudController::Lifecycles::BUILDPACK
            VCAP::CloudController::Diego::Buildpack::V3::LifecycleProtocol.new
          elsif lifecycle_type == VCAP::CloudController::Lifecycles::DOCKER
            VCAP::CloudController::Diego::Docker::V3::LifecycleProtocol.new
          end
        end
      end
    end
  end
end
