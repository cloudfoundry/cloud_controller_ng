module VCAP::CloudController
  class DeploymentModel < Sequel::Model(:deployments)
    DEPLOYING_STATE = 'DEPLOYING'.freeze
    DEPLOYED_STATE = 'DEPLOYED'.freeze

    many_to_one :app,
      class: 'VCAP::CloudController::AppModel',
      primary_key: :guid,
      key: :app_guid,
      without_guid_generation: true

    many_to_one :droplet,
      class: 'VCAP::CloudController::DropletModel',
      key: :droplet_guid,
      primary_key: :guid,
      without_guid_generation: true

    many_to_one :previous_droplet,
      class: 'VCAP::CloudController::DropletModel',
      key: :previous_droplet_guid,
      primary_key: :guid,
      without_guid_generation: true

    many_to_one :deploying_web_process,
      class: 'VCAP::CloudController::ProcessModel',
      key: :deploying_web_process_guid,
      primary_key: :guid,
      without_guid_generation: true

    dataset_module do
      def deploying_count
        where(state: DeploymentModel::DEPLOYING_STATE).count
      end
    end
  end
end
