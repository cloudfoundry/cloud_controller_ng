module VCAP::CloudController
  class DeploymentDelete
    class << self
      def delete(deployments)
        deployments.each do |deployment|
          delete_metadata(deployment)
          deployment.historical_related_processes.map(&:destroy)
          deployment.destroy
        end
      end

      private

      def delete_metadata(deployment)
        LabelDelete.delete(deployment.labels)
        AnnotationDelete.delete(deployment.annotations)
      end
    end
  end
end
