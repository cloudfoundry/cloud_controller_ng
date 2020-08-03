module VCAP::CloudController
  class AppKpackLifecycle
    def initialize(message)
      @message = message
    end

    def create_lifecycle_data_model(app)
      app.kpack_lifecycle_data = KpackLifecycleDataModel.create(app: app)
    end

    def update_lifecycle_data_model(app)
      if [update_lifecycle_data_buildpacks(app)].any?
        app.lifecycle_data.save
      end
    end

    def update_lifecycle_data_buildpacks(app)
      if @message.buildpack_data.requested?(:buildpacks)
        app.lifecycle_data.update(buildpacks: @message.buildpack_data.buildpacks)
      end
    end

    def valid?
      true
    end

    def errors
      []
    end

    def type
      Lifecycles::KPACK
    end
  end
end
