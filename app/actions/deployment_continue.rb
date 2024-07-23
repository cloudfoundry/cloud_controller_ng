module VCAP::CloudController
  class DeploymentContinue
    class Error < StandardError
    end
    class InvalidStatus < Error
    end

    class << self
      def continue(deployment:, user_audit_info:)
        deployment.db.transaction do
          deployment.lock!
          reject_invalid_state!(deployment) unless deployment.continuable?

          record_audit_event(deployment, user_audit_info)
          deployment.update(
            state: DeploymentModel::DEPLOYING_STATE,
            status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
            status_reason: DeploymentModel::DEPLOYING_STATUS_REASON
          )
        end
      end

      private

      def reject_invalid_state!(deployment)
        # TODO do we want better api errors? e.g. 
        # - this deployment will eventually be continuable
        # - this deployment is not continuable
        raise InvalidStatus.new("Cannot continue a deployment with status: #{deployment.status_value} and reason: #{deployment.status_reason}")
      end

      def record_audit_event(deployment, user_audit_info)
        app = deployment.app
        Repositories::DeploymentEventRepository.record_continue(
          deployment,
          deployment.droplet,
          user_audit_info,
          app.name,
          app.space_guid,
          app.space.organization_guid
        )
      end
    end
  end
end
