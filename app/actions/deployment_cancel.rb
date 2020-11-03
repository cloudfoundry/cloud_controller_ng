module VCAP::CloudController
  class DeploymentCancel
    class Error < StandardError
    end
    class InvalidStatus < Error
    end
    class SetCurrentDropletError < Error
    end

    class << self
      def cancel(deployment:, user_audit_info:)
        deployment.db.transaction do
          deployment.lock!
          reject_invalid_state!(deployment) unless deployment.cancelable?

          begin
            AppAssignDroplet.new(user_audit_info).assign(deployment.app, deployment.previous_droplet)
          rescue AppAssignDroplet::Error => e
            raise SetCurrentDropletError.new(e)
          end
          record_audit_event(deployment, user_audit_info)
          deployment.update(
            state: DeploymentModel::CANCELING_STATE,
            status_value: DeploymentModel::ACTIVE_STATUS_VALUE,
            status_reason: DeploymentModel::CANCELING_STATUS_REASON
          )
        end
      end

      private

      def reject_invalid_state!(deployment)
        raise InvalidStatus.new("Cannot cancel a deployment with status: #{deployment.status_value} and reason: #{deployment.status_reason}")
      end

      def record_audit_event(deployment, user_audit_info)
        app = deployment.app
        Repositories::DeploymentEventRepository.record_cancel(
          deployment,
          deployment.droplet,
          user_audit_info,
          app.name,
          app.space_guid,
          app.space.organization_guid,
        )
      end
    end
  end
end
