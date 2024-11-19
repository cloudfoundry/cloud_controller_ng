module VCAP::CloudController
  module DeploymentUpdater
    module Calculators
      class AllInstancesRoutable
        attr_reader :deployment, :logger

        def initialize(deployment, logger)
          @deployment = deployment
          @logger = logger
        end

        def call
          instances = instance_reporters.all_instances_for_app(deployment.deploying_web_process)
          instances.all? { |_, val| val[:state] == VCAP::CloudController::Diego::LRP_RUNNING && val[:routable] }
        rescue CloudController::Errors::ApiError # the instances_reporter re-raises InstancesUnavailable as ApiError
          logger.info("skipping-deployment-update-for-#{deployment.guid}")
          false
        end

        def instance_reporters
          CloudController::DependencyLocator.instance.instances_reporters
        end
      end
    end
  end
end
