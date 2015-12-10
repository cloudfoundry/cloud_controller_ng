require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class DockerLifecycleDataModel
    LIFECYCLE_TYPE = Lifecycles::DOCKER

    def to_hash
      {}
    end
  end
end
