module VCAP::CloudController
  class DeploymentModel < Sequel::Model(:deployments)
    DEPLOYMENT_STATES = [
      DEPLOYING_STATE = 'DEPLOYING'.freeze,
      DEPLOYED_STATE = 'DEPLOYED'.freeze,
      CANCELING_STATE = 'CANCELING'.freeze,
      CANCELED_STATE = 'CANCELED'.freeze
    ].freeze

    STATUS_VALUES = [
      FINALIZED_STATUS_VALUE = 'FINALIZED'.freeze,
      ACTIVE_STATUS_VALUE = 'ACTIVE'.freeze
    ].freeze

    STATUS_REASONS = [
      DEPLOYED_STATUS_REASON = 'DEPLOYED'.freeze,
      DEPLOYING_STATUS_REASON = 'DEPLOYING'.freeze,
      CANCELED_STATUS_REASON = 'CANCELED'.freeze,
      CANCELING_STATUS_REASON = 'CANCELING'.freeze,
      SUPERSEDED_STATUS_REASON = 'SUPERSEDED'.freeze,
      DEGENERATE_STATUS_REASON = 'DEGENERATE'.freeze
    ].freeze

    DEPLOYMENT_STRATEGIES = [
      ROLLING_STRATEGY = 'rolling'.freeze,
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

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    dataset_module do
      def deploying_count
        where(state: DeploymentModel::DEPLOYING_STATE).count
      end
    end

    def deploying?
      state == DEPLOYING_STATE
    end

    def cancelable?
      valid_states_for_cancel = [DeploymentModel::DEPLOYING_STATE,
                                 DeploymentModel::CANCELING_STATE]
      valid_states_for_cancel.include?(state)
    end
  end
end
