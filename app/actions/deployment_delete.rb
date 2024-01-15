module VCAP::CloudController
  class DeploymentDelete
    class << self
      def delete(deployments)
        deployments.each do |deployment|
          deployment.historical_related_processes.map(&:destroy)
          deployment.destroy
        end
      end

      def delete_for_app(guid)
        DeploymentModel.db.transaction do
          app_deployments_dataset = DeploymentModel.where(app_guid: guid)
          DeploymentProcessModel.where(deployment_guid: app_deployments_dataset.select(:guid)).delete
          DeploymentLabelModel.where(resource_guid: app_deployments_dataset.select(:guid)).delete
          DeploymentAnnotationModel.where(resource_guid: app_deployments_dataset.select(:guid)).delete
          app_deployments_dataset.delete
        end
      end
    end
  end
end
