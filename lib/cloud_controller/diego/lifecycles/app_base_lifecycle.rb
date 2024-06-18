module VCAP::CloudController
  class AppBaseLifecycle
    def update_lifecycle_data_model(app)
      if [update_lifecycle_data_buildpacks(app),
          update_lifecycle_data_stack(app)].any?
        app.lifecycle_data.save
      end
    end

    def update_lifecycle_data_buildpacks(app)
      return unless message.buildpack_data.requested?(:buildpacks)

      app.lifecycle_data.buildpacks = buildpacks
    end

    def update_lifecycle_data_stack(app)
      return unless message.buildpack_data.requested?(:stack)

      app.lifecycle_data.stack = message.buildpack_data.stack
    end

    private

    attr_reader :message

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
