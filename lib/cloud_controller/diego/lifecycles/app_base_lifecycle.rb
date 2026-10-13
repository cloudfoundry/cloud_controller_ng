module VCAP::CloudController
  class AppBaseLifecycle
    def update_lifecycle_data_model(app)
      if [update_lifecycle_data_buildpacks(app),
          update_lifecycle_data_stack(app),
          update_lifecycle_data_credentials(app)].any?
        app.lifecycle_data.save
      end
    end

    def update_lifecycle_data_buildpacks(app)
      return unless message.buildpack_data.requested?(:buildpacks)

      app.lifecycle_data.buildpacks = buildpacks
      true
    end

    def update_lifecycle_data_stack(app)
      return unless message.buildpack_data.requested?(:stack)

      app.lifecycle_data.stack = message.buildpack_data.stack
      true
    end

    def update_lifecycle_data_credentials(app)
      return unless message.buildpack_data.requested?(:credentials)
      return unless app.lifecycle_data.respond_to?(:credentials=)

      app.lifecycle_data.credentials = message.buildpack_data.credentials
      true
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
