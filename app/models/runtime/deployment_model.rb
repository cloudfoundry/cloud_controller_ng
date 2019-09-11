module VCAP::CloudController
  class DeploymentModel < Sequel::Model(:deployments)
    DEPLOYMENT_STATES = [
      DEPLOYING_STATE = 'DEPLOYING'.freeze,
      DEPLOYED_STATE = 'DEPLOYED'.freeze,
      CANCELING_STATE = 'CANCELING'.freeze,
      CANCELED_STATE = 'CANCELED'.freeze
    ].freeze

    STATUS_VALUES = [
      DEPLOYING_STATUS_VALUE = 'DEPLOYING'.freeze,
      FINALIZED_STATUS_VALUE = 'FINALIZED'.freeze,
      CANCELING_STATUS_VALUE = 'CANCELING'.freeze
    ].freeze

    STATUS_REASONS = [
      DEPLOYED_STATUS_REASON = 'DEPLOYED'.freeze,
      CANCELED_STATUS_REASON = 'CANCELED'.freeze,
      SUPERSEDED_STATUS_REASON = 'SUPERSEDED'.freeze,
      DEGENERATE_STATUS_REASON = 'DEGENERATE'.freeze
    ].freeze

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

    one_to_many :historical_related_processes,
      class: 'VCAP::CloudController::DeploymentProcessModel',
      key: :deployment_guid,
      primary_key: :guid,
      without_guid_generation: true

    one_to_many :labels, class: 'VCAP::CloudController::DeploymentLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::DeploymentAnnotationModel', key: :resource_guid, primary_key: :guid

    dataset_module do
      def deploying_count
        where(state: DeploymentModel::DEPLOYING_STATE).count
      end
    end

    def deploying?
      state == DEPLOYING_STATE
    end
  end
end
