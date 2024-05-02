module VCAP::CloudController
  module Diego
    module LifecycleProtocol
      def self.protocol_for_type(lifecycle_type)
        case lifecycle_type
        when VCAP::CloudController::Lifecycles::BUILDPACK
          VCAP::CloudController::Diego::Buildpack::LifecycleProtocol.new
        when VCAP::CloudController::Lifecycles::DOCKER
          VCAP::CloudController::Diego::Docker::LifecycleProtocol.new
        when VCAP::CloudController::Lifecycles::CNB
          VCAP::CloudController::Diego::CNB::LifecycleProtocol.new
        end
      end
    end
  end
end
