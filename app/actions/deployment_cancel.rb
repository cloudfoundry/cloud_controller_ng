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
          reject_invalid_state!(deployment) unless valid_state?(deployment)

          begin
            AppAssignDroplet.new(user_audit_info).assign(deployment.app, deployment.previous_droplet)
          rescue AppAssignDroplet::Error => e
            raise SetCurrentDropletError.new(e)
          end
          record_audit_event(deployment, user_audit_info)
          deployment.update(
            state: DeploymentModel::CANCELING_STATE,
            status_value: DeploymentModel::CANCELING_STATUS_VALUE
          )
        end
      end

      private

      def valid_state?(deployment)
        valid_states_for_cancel = [DeploymentModel::DEPLOYING_STATE,
                                     DeploymentModel::CANCELING_STATE]
        valid_states_for_cancel.include?(deployment.state)
      end

      def reject_invalid_state!(deployment)
        raise InvalidStatus.new("Cannot cancel a deployment with status: #{deployment.status_value} and reason:#{deployment.status_reason}")
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
