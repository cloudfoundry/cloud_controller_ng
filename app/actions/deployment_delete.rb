module VCAP::CloudController
  class DeploymentDelete
    class << self
      def delete(deployments)
        deployments.delete
      end

      def delete_for_app(guid)
        DeploymentModel.where(app_guid: guid).delete
      end
    end
  end
end
