require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class AppBuildpackLifecycle
    def initialize(message)
      @message = message

      db_result       = BuildpackLifecycleFetcher.fetch(buildpacks, stack)
      @validator      = BuildpackLifecycleDataValidator.new({
        buildpack_infos: db_result[:buildpack_infos],
        stack: db_result[:stack],
      })
    end

    delegate :valid?, :errors, to: :validator

    def create_lifecycle_data_model(app)
      BuildpackLifecycleDataModel.create(
        buildpacks: buildpacks,
        stack:     stack,
        app:       app
      )
    end

    def update_lifecycle_data_model(app)
      if [update_lifecycle_data_buildpacks(app),
          update_lifecycle_data_stack(app)].any?
        app.lifecycle_data.save
      end
    end

    def update_lifecycle_data_buildpacks(app)
      if message.buildpack_data.requested?(:buildpacks)
        app.lifecycle_data.buildpacks = buildpacks
      end
    end

    def update_lifecycle_data_stack(app)
      if message.buildpack_data.requested?(:stack)
        app.lifecycle_data.stack = message.buildpack_data.stack
      end
    end

    def type
      Lifecycles::BUILDPACK
    end

    private

    attr_reader :message, :validator

    def buildpacks
      message.buildpack_data.requested?(:buildpacks) ? (message.buildpack_data.buildpacks || []) : []
    end

    def stack
      if message.buildpack_data.requested?(:stack) && !message.buildpack_data.stack.nil?
        message.buildpack_data.stack
      else
        Stack.default.name
      end
    end
  end
end
