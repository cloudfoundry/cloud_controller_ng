module VCAP::CloudController
  class DeploymentModel < Sequel::Model(:deployments)
    DEPLOYMENT_STATES = [
      DEPLOYING_STATE = 'DEPLOYING'.freeze,
      PREPAUSED_STATE = 'PREPAUSED'.freeze,
      PAUSED_STATE = 'PAUSED'.freeze,
      DEPLOYED_STATE = 'DEPLOYED'.freeze,
      CANCELING_STATE = 'CANCELING'.freeze,
      CANCELED_STATE = 'CANCELED'.freeze
    ].freeze

    STATUS_VALUES = [
      FINALIZED_STATUS_VALUE = 'FINALIZED'.freeze,
      ACTIVE_STATUS_VALUE = 'ACTIVE'.freeze
    ].freeze

    STATUS_REASONS = [
      DEPLOYING_STATUS_REASON = 'DEPLOYING'.freeze,
      PAUSED_STATUS_REASON = 'PAUSED'.freeze,
      DEPLOYED_STATUS_REASON = 'DEPLOYED'.freeze,
      CANCELED_STATUS_REASON = 'CANCELED'.freeze,
      CANCELING_STATUS_REASON = 'CANCELING'.freeze,
      SUPERSEDED_STATUS_REASON = 'SUPERSEDED'.freeze
    ].freeze

    DEPLOYMENT_STRATEGIES = [
      ROLLING_STRATEGY = 'rolling'.freeze,
      CANARY_STRATEGY = 'canary'.freeze
    ].freeze

    PROGRESSING_STATES = [
      DEPLOYING_STATE,
      PREPAUSED_STATE,
      PAUSED_STATE
    ].freeze

    ACTIVE_STATES = [
      *PROGRESSING_STATES,
      CANCELING_STATE
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

    add_association_dependencies historical_related_processes: :destroy
    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    dataset_module do
      def deploying_count
        where(state: DeploymentModel::PROGRESSING_STATES).count
      end
    end

    def before_update
      super
      set_status_updated_at
    end

    def deploying?
      DeploymentModel::PROGRESSING_STATES.include?(state)
    end

    def cancelable?
      DeploymentModel::ACTIVE_STATES.include?(state)
    end

    def continuable?
      state == DeploymentModel::PAUSED_STATE
    end

    private

    def set_status_updated_at
      return unless column_changed?(:status_reason) || column_changed?(:status_value)

      self.status_updated_at = updated_at
    end
  end
end
