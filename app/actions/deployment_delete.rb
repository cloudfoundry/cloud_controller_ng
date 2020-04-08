module VCAP::CloudController
  class DeploymentDelete
    class << self
      def delete(deployments)
        deployments.each do |deployment|
          deployment.historical_related_processes.map(&:destroy)
          deployment.destroy
        end
      end
    end
  end
end
