require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class DockerLifecycleDataModel
    LIFECYCLE_TYPE = Lifecycles::DOCKER

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

    def validate; end

    def valid?
      true
    end

    def to_hash
      {}
    end
  end
end
