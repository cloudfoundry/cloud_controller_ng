module VCAP::CloudController
  class DeploymentCancel
    class Error < StandardError; end
    class InvalidState < Error; end
    class SetCurrentDropletError < Error; end

    class << self
      def cancel(deployment:, user_audit_info:)
        reject_invalid_states!(deployment) if invalid_states?(deployment)

        deployment.db.transaction do
          deployment.lock!

          app = deployment.app
          original_web_process = app.web_process
          deploying_web_process = deployment.deploying_web_process

          app.lock!
          original_web_process.lock!
          deploying_web_process.lock!

          begin
            SetCurrentDroplet.new(user_audit_info).update_to(app, deployment.previous_droplet)
          rescue SetCurrentDroplet::Error => e
            raise SetCurrentDropletError.new(e)
          end

          RouteMappingModel.where(app: app, process_type: deploying_web_process.type).map(&:delete)

          original_web_process.update(
            instances: infer_original_instance_count(original_web_process, deploying_web_process)
          )

          deploying_web_process.delete

          deployment.update(state: DeploymentModel::CANCELED_STATE)
        end
      end

      private

      def infer_original_instance_count(original_web_process, deploying_web_process)
        if original_web_process.instances <= 1
          deploying_web_process.instances
        else
          original_web_process.instances + deploying_web_process.instances - 1
        end
      end

      def invalid_states?(deployment)
        [DeploymentModel::DEPLOYED_STATE, DeploymentModel::CANCELED_STATE].include? deployment.state
      end

      def reject_invalid_states!(deployment)
        raise InvalidState.new("Cannot cancel a #{deployment.state} deployment")
      end
    end
  end
end
