module VCAP
  module CloudController
    class DeploymentModelTestFactory
      class << self
        def make(*)
          deployment = DeploymentModel.make(*)
          DeploymentProcessModel.make(
            deployment: deployment,
            process_guid: deployment.deploying_web_process.guid,
            process_type: deployment.deploying_web_process.type
          )
          deployment
        end
      end
    end
  end
end
