require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/lifecycle_base'
require 'cloud_controller/diego/lifecycles/buildpack_lifecycle_data_validator'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class BuildpackLifecycle < LifecycleBase
    def type
      Lifecycles::BUILDPACK
    end

    def create_lifecycle_data_model(build)
      VCAP::CloudController::BuildpackLifecycleDataModel.create(
        buildpacks: Array(buildpacks_to_use),
        stack: staging_stack,
        build: build
      )
    end

    def staging_environment_variables
      {
        'CF_STACK' => staging_stack
      }
    end

    def skip_detect?
      !buildpack_infos.empty?
    end

    private

    def app_stack
      @package.app.buildpack_lifecycle_data.try(:stack)
    end
  end
end
