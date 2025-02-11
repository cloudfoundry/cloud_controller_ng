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
        credentials:,
        app:
      )
    end

    def valid?
      message.is_a?(AppUpdateMessage) || !buildpacks.empty?
    end

    def errors
      []
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
  end
end
