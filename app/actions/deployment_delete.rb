module VCAP::CloudController
  class DeploymentDelete
    def self.delete(deployments)
      deployments.each(&:destroy)
    end
  end
end
