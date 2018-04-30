module VCAP::CloudController
  class DeploymentDelete
    def delete(deployments)
      deployments.each(&:destroy)
    end
  end
end
