require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class DockerLifecycleDataModel
    LIFECYCLE_TYPE = Lifecycles::DOCKER

    def buildpack_model
      AutoDetectionBuildpack.new
    end

    def to_hash
      {}
    end
  end
end
