module VCAP::CloudController
  class DeploymentCancel
    class Error < StandardError; end
    class InvalidState < Error; end
    class SetCurrentDropletError < Error; end

    class << self
      def cancel(deployment:, user_audit_info:)
        deployment.db.transaction do
          deployment.lock!
          reject_invalid_states!(deployment) unless valid_state?(deployment)

          begin
            AppAssignDroplet.new(user_audit_info).assign(deployment.app, deployment.previous_droplet)
          rescue AppAssignDroplet::Error => e
            raise SetCurrentDropletError.new(e)
          end
          record_audit_event(deployment, user_audit_info)
          deployment.update(state: DeploymentModel::CANCELING_STATE)
        end
      end

      private

      def valid_state?(deployment)
        DeploymentModel::CANCELABLE_STATES.include?(deployment.state)
      end

      def reject_invalid_states!(deployment)
        raise InvalidState.new("Cannot cancel a #{deployment.state} deployment")
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
