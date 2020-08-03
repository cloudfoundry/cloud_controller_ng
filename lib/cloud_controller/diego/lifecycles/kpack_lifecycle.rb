require 'cloud_controller/diego/lifecycles/kpack_lifecycle_data_validator'

module VCAP::CloudController
  class KpackLifecycle
    attr_reader :staging_message

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package
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

    def buildpack_infos
      @buildpack_infos ||= requested_and_available_buildpacks(buildpacks_to_use)
    end

    def validator
      @validator ||= KpackLifecycleDataValidator.new(
        requested_buildpacks: buildpacks_to_use,
        buildpack_infos: buildpack_infos
      )
    end

    private

    def buildpacks_to_use
      requested_buildpacks = @staging_message.buildpack_data.buildpacks

      return requested_buildpacks unless requested_buildpacks.nil? || requested_buildpacks.empty?

      @package&.app&.kpack_lifecycle_data&.buildpacks || []
    end

    def requested_and_available_buildpacks(buildpacks_to_use)
      return [] if buildpacks_to_use.empty?

      buildpacks_to_use & KpackBuildpackListFetcher.new.fetch_all.map(&:name)
    end
  end
end
