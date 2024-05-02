require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class CNBLifecycle
    attr_reader :staging_message, :buildpack_infos

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package = package

      db_result = BuildpackLifecycleFetcher.fetch(buildpacks_to_use, staging_stack)
      @buildpack_infos = db_result[:buildpack_infos]
      @validator = BuildpackLifecycleDataValidator.new({ buildpack_infos: buildpack_infos, stack: db_result[:stack] })
    end

    delegate :valid?, :errors, to: :validator

    def type
      Lifecycles::CNB
    end

    def create_lifecycle_data_model(build)
      VCAP::CloudController::CNBLifecycleDataModel.create(
        buildpacks: Array(buildpacks_to_use),
        stack: staging_stack,
        build: build
      )
    end

    def staging_environment_variables
      {}
    end

    def staging_stack
      requested_stack || app_stack || VCAP::CloudController::Stack.default.name
    end

    private

    def buildpacks_to_use
      staging_message.buildpack_data.buildpacks || @package.app.lifecycle_data.buildpacks
    end

    def requested_stack
      @staging_message.buildpack_data.stack
    end

    def app_stack
      @package.app.cnb_lifecycle_data.try(:stack)
    end

    attr_reader :validator
  end
end
