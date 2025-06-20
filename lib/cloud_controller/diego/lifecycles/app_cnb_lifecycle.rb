require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'
require 'cloud_controller/diego/lifecycles/app_base_lifecycle'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class AppCNBLifecycle < AppBaseLifecycle
    def initialize(message)
      @message = message

      db_result       = BuildpackLifecycleFetcher.fetch(buildpacks, stack, type)
      @validator      = BuildpackLifecycleDataValidator.new({
                                                              buildpack_infos: db_result[:buildpack_infos],
                                                              stack: db_result[:stack]
                                                            })
    end

    delegate :valid?, :errors, to: :validator

    def create_lifecycle_data_model(app)
      CNBLifecycleDataModel.create(
        buildpacks:,
        stack:,
        credentials:,
        app:
      )
    end

    def update_lifecycle_data_credentials(app)
      return unless message.buildpack_data.requested?(:credentials)

      app.lifecycle_data.credentials = message.buildpack_data.credentials
    end

    def type
      Lifecycles::CNB
    end

    def credentials
      message.buildpack_data.credentials
    end

    private

    attr_reader :validator
  end
end
