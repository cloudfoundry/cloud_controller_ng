require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'
require 'cloud_controller/diego/lifecycles/app_base_lifecycle'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class AppBuildpackLifecycle < AppBaseLifecycle
    def initialize(message)
      @message = message

      db_result       = BuildpackLifecycleFetcher.fetch(buildpacks, stack)
      @validator      = BuildpackLifecycleDataValidator.new({
                                                              buildpack_infos: db_result[:buildpack_infos],
                                                              stack: db_result[:stack]
                                                            })
    end

    delegate :valid?, :errors, to: :validator

    def create_lifecycle_data_model(app)
      BuildpackLifecycleDataModel.create(
        buildpacks:,
        stack:,
        app:
      )
    end

    def type
      Lifecycles::BUILDPACK
    end

    private

    attr_reader :validator
  end
end
