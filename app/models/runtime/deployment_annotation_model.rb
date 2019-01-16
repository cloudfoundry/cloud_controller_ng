module VCAP::CloudController
  class DeploymentAnnotationModel < Sequel::Model(:deployment_annotations)
    many_to_one :deployment,
                class: 'VCAP::CloudController::DeploymentModel',
                primary_key: :guid,
                key: :resource_guid,
                without_guid_generation: true
  end
end
