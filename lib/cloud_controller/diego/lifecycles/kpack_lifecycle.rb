module VCAP::CloudController
  class KpackLifecycle
    attr_reader :staging_message, :buildpack_infos

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package
      @buildpack_infos = KpackBuildpackListFetcher.new.fetch(staging_message.buildpack_data.buildpacks)
    end

    def type
      Lifecycles::KPACK
    end

    def create_lifecycle_data_model(build)
      VCAP::CloudController::KpackLifecycleDataModel.create(
        build: build,
      )
    end

    def staging_environment_variables
      {}
    end

    def valid?
      true
    end

    def errors
      []
    end

    def stack
      nil
    end
  end
end
