require 'cloud_controller/diego/lifecycles/app_base_lifecycle'

module VCAP::CloudController
  class AppBuildpackLifecycle < AppBaseLifecycle
    def create_lifecycle_data_model(app)
      app.buildpack_lifecycle_data = BuildpackLifecycleDataModel.create(
        buildpacks: buildpacks,
        stack: stack,
        credentials: message.buildpack_data.credentials,
        app: app
      )
    end

    def type
      Lifecycles::BUILDPACK
    end
  end
end
