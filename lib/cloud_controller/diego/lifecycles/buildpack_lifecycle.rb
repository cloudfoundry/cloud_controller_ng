require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class BuildpackLifecycle
    attr_reader :staging_message, :buildpack_infos

    def initialize(package, staging_message)
      @staging_message = staging_message
      @package         = package

      db_result = BuildpackLifecycleFetcher.fetch(buildpacks_to_use, staging_stack)
      @buildpack_infos = db_result[:buildpack_infos]
      @validator = BuildpackLifecycleDataValidator.new({ buildpack_infos: buildpack_infos, stack: db_result[:stack] })
    end

    delegate :valid?, :errors, to: :validator

    def type
      Lifecycles::BUILDPACK
    end

    def create_lifecycle_data_model(build)
      VCAP::CloudController::BuildpackLifecycleDataModel.create(
        buildpacks: Array(buildpacks_to_use),
        stack:     staging_stack,
        build:     build
      )
    end

    def staging_environment_variables
      {
        'CF_STACK' => staging_stack
      }
    end

    def staging_stack
      requested_stack || app_stack || buildpack_stack || VCAP::CloudController::Stack.default.name
    end

    private

    def buildpacks_to_use
      if staging_message.buildpack_data.buildpacks
        staging_message.buildpack_data.buildpacks
      else
        @package.app.lifecycle_data.buildpacks
      end
    end

    def requested_stack
      @staging_message.buildpack_data.stack
    end

    def app_stack
      @package.app.buildpack_lifecycle_data.try(:stack)
    end

    def buildpack_stack
      stacks = Buildpack.where(name: buildpacks_to_use).select(:stack).map(&:stack).uniq
      if stacks.length == 1
        stacks.first
      end
    end

    attr_reader :validator
  end
end
