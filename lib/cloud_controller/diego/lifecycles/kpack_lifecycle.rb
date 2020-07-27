require 'cloud_controller/diego/lifecycles/kpack_lifecycle_data_validator'

module VCAP::CloudController
  class KpackLifecycle
    attr_reader :staging_message, :buildpack_infos

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package

      # It is weird we need to pass a dummy list message here
      # TODO: extract a common way to get the unfiltered list of buildpacks that can then have filters applied if needed?
      # TODO: Don't reach out to k8s unless buildpacks are requested
      available_buildpacks = KpackBuildpackListFetcher.new.fetch_all(BuildpacksListMessage.from_params({}))
      requested_buildpacks = if staging_message.buildpack_data.buildpacks.nil?
                               []
                             else
                               staging_message.buildpack_data.buildpacks
                             end
      @buildpack_infos = requested_buildpacks.select { |bp| available_buildpacks.include?({ name: bp }) }
      @validator = KpackLifecycleDataValidator.new({ requested_buildpacks: requested_buildpacks, buildpack_infos: buildpack_infos })
    end

    delegate :valid?, :errors, to: :validator

    def type
      Lifecycles::KPACK
    end

    def create_lifecycle_data_model(build)
      VCAP::CloudController::KpackLifecycleDataModel.create(
        buildpacks: buildpack_infos,
        build: build,
      )
    end

    def staging_environment_variables
      {}
    end

    def stack
      nil
    end

    attr_reader :validator
  end
end
