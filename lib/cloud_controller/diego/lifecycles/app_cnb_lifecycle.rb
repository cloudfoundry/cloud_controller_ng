require 'cloud_controller/diego/lifecycles/cnb_lifecycle_data_validator'
require 'cloud_controller/diego/lifecycles/app_base_lifecycle'

module VCAP::CloudController
  class AppCNBLifecycle < AppBaseLifecycle
    def create_lifecycle_data_model(app)
      app.cnb_lifecycle_data = CNBLifecycleDataModel.create(
        buildpacks: buildpacks,
        stack: stack,
        credentials: message.buildpack_data.credentials,
        app: app
      )
    end

    def type
      Lifecycles::CNB
    end

    private

    def validator_class
      CNBLifecycleDataValidator
    end
  end
end
