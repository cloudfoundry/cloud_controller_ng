module VCAP::CloudController
  class DeploymentCancel
    class Error < StandardError; end
    class InvalidState < Error; end
    class SetCurrentDropletError < Error; end

    class << self
      def cancel(deployment:, user_audit_info:)
        deployment.db.transaction do
          deployment.lock!
          reject_invalid_states!(deployment) if invalid_states?(deployment)

          begin
            SetCurrentDroplet.new(user_audit_info).update_to(deployment.app, deployment.previous_droplet)
          rescue SetCurrentDroplet::Error => e
            raise SetCurrentDropletError.new(e)
          end

          deployment.update(state: DeploymentModel::CANCELING_STATE)
        end
      end

      private

      def invalid_states?(deployment)
        [DeploymentModel::DEPLOYED_STATE, DeploymentModel::CANCELED_STATE].include? deployment.state
      end

      def reject_invalid_states!(deployment)
        raise InvalidState.new("Cannot cancel a #{deployment.state} deployment")
      end
    end
  end
end
