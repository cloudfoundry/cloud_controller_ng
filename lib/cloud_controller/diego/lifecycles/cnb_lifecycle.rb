require 'cloud_controller/diego/lifecycles/buildpack_info'
require 'cloud_controller/diego/lifecycles/lifecycle_base'
require 'cloud_controller/diego/lifecycles/cnb_lifecycle_data_validator'
require 'fetchers/buildpack_lifecycle_fetcher'

module VCAP::CloudController
  class CNBLifecycle < LifecycleBase
    def type
      Lifecycles::CNB
    end

    def create_lifecycle_data_model(build)
      build.cnb_lifecycle_data = VCAP::CloudController::CNBLifecycleDataModel.create(
        buildpacks: Array(buildpacks_to_use),
        stack: staging_stack,
        build: build,
        credentials: credentials_for_staging
      )
    end

    def staging_environment_variables
      {}
    end

    def credentials
      Oj.dump(credentials_for_staging)
    end

    private

    def validator_class
      CNBLifecycleDataValidator
    end

    def app_stack
      @package.app.cnb_lifecycle_data.try(:stack)
    end
  end
end
