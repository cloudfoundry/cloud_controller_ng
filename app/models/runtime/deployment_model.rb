module VCAP::CloudController
  class DeploymentModel < Sequel::Model(:deployments)
    DEPLOYMENT_STATES = [
      DEPLOYING_STATE = 'DEPLOYING'.freeze,
      DEPLOYED_STATE = 'DEPLOYED'.freeze,
      CANCELING_STATE = 'CANCELING'.freeze,
      FAILING_STATE = 'FAILING'.freeze,
      FAILED_STATE = 'FAILED'.freeze,
      CANCELED_STATE = 'CANCELED'.freeze
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

    def failing?
      state == FAILING_STATE
    end

    def should_fail?
      timeout = deploying_web_process.health_check_timeout || Config.config.get(:default_health_check_timeout)
      state == DEPLOYING_STATE && last_healthy_at < (Time.now - 2 * timeout.seconds)
    end
  end
end
