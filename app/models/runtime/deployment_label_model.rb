module VCAP::CloudController
  class DeploymentLabelModel < Sequel::Model(:deployment_labels)
    many_to_one :deployment,
      class: 'VCAP::CloudController::DeploymentModel',
      primary_key: :guid,
      key: :resource_guid,
      without_guid_generation: true
  end
end
