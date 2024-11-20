module VCAP::CloudController
  module DeploymentUpdater
    module Calculators
      class InstancesToScaleDown
        attr_reader :deployment, :process

        def initialize(deployment, process)
          @deployment = deployment
          @process = process
        end

        def call
          [(process.instances - deployment.max_in_flight), 0].max
        end
      end
    end
  end
end
