module VCAP::CloudController
  module DeploymentUpdater
    module Calculators
      class InstancesToScaleUp
        attr_reader :deployment

        def initialize(deployment)
          @deployment = deployment
        end

        def call
          [deployment.deploying_web_process.instances + deployment.max_in_flight, deployment.original_web_process_instance_count].min
        end
      end
    end
  end
end
