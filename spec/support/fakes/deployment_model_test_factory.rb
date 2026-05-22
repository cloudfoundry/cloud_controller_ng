module VCAP
  module CloudController
    class DeploymentModelTestFactory
      class << self
        def make(*)
          deployment = FactoryBot.create(:deployment_model, *)
          FactoryBot.create(:deployment_process_model,
                            deployment: deployment,
                            process_guid: deployment.deploying_web_process.guid,
                            process_type: deployment.deploying_web_process.type)
          deployment
        end
      end
    end
  end
end
