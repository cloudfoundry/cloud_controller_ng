require 'cloud_controller/diego/lifecycles/kpack_lifecycle_data_validator'

module VCAP::CloudController
  class KpackLifecycle
    attr_reader :staging_message, :buildpack_infos

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package

      @buildpack_infos = requested_and_available_buildpacks(buildpacks_to_use)
      @validator = KpackLifecycleDataValidator.new(
        requested_buildpacks: buildpacks_to_use,
        buildpack_infos: buildpack_infos
      )
    end

    delegate :valid?, :errors, to: :validator

    def type
      Lifecycles::KPACK
    end

    def create_lifecycle_data_model(build)
      VCAP::CloudController::KpackLifecycleDataModel.create(
        build: build,
        buildpacks: buildpacks_to_use,
      )
    end

    def staging_environment_variables
      {}
    end

    def stack
      nil
    end

    attr_reader :validator

    private

    def buildpacks_to_use
      requested_buildpacks = @staging_message.buildpack_data.buildpacks

      return requested_buildpacks unless requested_buildpacks.nil? || requested_buildpacks.empty?

      @package&.app&.kpack_lifecycle_data&.buildpacks || []
    end

    def requested_and_available_buildpacks(buildpacks_to_use)
      # TODO: extract a common way to get the unfiltered list of buildpacks that can then have filters applied if needed?
      # TODO: Don't reach out to k8s unless buildpacks are requested
      available_buildpack_names = KpackBuildpackListFetcher.new.fetch_all(BuildpacksListMessage.from_params({})).map(&:name)

      buildpacks_to_use & available_buildpack_names
    end
  end
end
