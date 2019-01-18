module VCAP::CloudController
  class DeploymentUpdate
    class Error < ::StandardError
    end

    def self.update(deployment, message)
      deployment.db.transaction do
        deployment.lock!
        LabelsUpdate.update(deployment, message.labels, DeploymentLabelModel)
        AnnotationsUpdate.update(deployment, message.annotations, DeploymentAnnotationModel)
        deployment.save
      end

      deployment
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end
  end
end
