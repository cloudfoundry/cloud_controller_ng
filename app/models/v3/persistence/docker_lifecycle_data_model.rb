require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class DockerLifecycleDataModel
    LIFECYCLE_TYPE = Lifecycles::DOCKER
    def legacy_buildpack_model
      AutoDetectionBuildpack.new
    end

    def buildpacks
      []
    end

    def buildpack_models
      [AutoDetectionBuildpack.new]
    end

    def using_custom_buildpack?
      false
    end

    def first_custom_buildpack_url
      nil
    end

    def to_hash
      {}
    end
  end
end
