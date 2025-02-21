module VCAP::CloudController
  class DeploymentModel < Sequel::Model(:deployments)
    plugin :serialization

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

    serialize_attributes :json, :canary_steps

    dataset_module do
      def deploying_count
        where(state: DeploymentModel::PROGRESSING_STATES).count
      end
    end

    def before_update
      super
      set_status_updated_at
    end

    def before_create
      self.canary_current_step = 1 if strategy == DeploymentModel::CANARY_STRATEGY

      # unless canary_steps.nil?
      #   # ensure that canary steps are in the correct format for serialization
      #   self.canary_steps = canary_steps.map(&:stringify_keys)
      # end
      super
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

    def current_canary_instance_target
      canary_step[:canary]
    end

    def canary_total_instances
      canary_step[:canary] + canary_step[:original]
    end

    def canary_step
      raise 'canary_step is only valid for canary deloyments' unless strategy == CANARY_STRATEGY

      current_step = canary_current_step || 1
      canary_step_plan[current_step - 1]
    end

    def canary_step_plan
      raise 'canary_step_plan is only valid for canary deloyments' unless strategy == CANARY_STRATEGY

      return [{ canary: 1, original: original_web_process_instance_count }] if canary_steps.nil?

      canary_steps.map do |step|
        weight = step['instance_weight']
        target_canary = (original_web_process_instance_count * (weight.to_f / 100)).round.to_i
        target_canary = 1 if target_canary.zero?
        target_original = original_web_process_instance_count - target_canary + 1
        target_original = 0 if weight == 100
        { canary: target_canary, original: target_original }
      end
    end

    private

    def set_status_updated_at
      return unless column_changed?(:status_reason) || column_changed?(:status_value)

      self.status_updated_at = updated_at
    end
  end
end
