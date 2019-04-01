module VCAP::CloudController
  class DeploymentProcessModel < Sequel::Model(:deployment_processes)
    many_to_one :deployment,
                class: 'VCAP::CloudController::DeploymentModel',
                key: :deployment_guid,
                primary_key: :guid,
                without_guid_generation: true
  end
end
