require 'cloud_controller/diego/lifecycles/app_base_lifecycle'

module VCAP::CloudController
  class AppCNBLifecycle < AppBaseLifecycle
    def initialize(message)
      @message = message
    end

    def create_lifecycle_data_model(app)
      CNBLifecycleDataModel.create(
        buildpacks:,
        stack:,
        app:
      )
    end

    def valid?
      !buildpacks.empty?
    end

    def errors
      []
    end

    def type
      Lifecycles::CNB
    end
  end
end
