module VCAP::CloudController
  class AppUpdate
    class DropletNotFound < StandardError; end
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
      @logger     = Steno.logger('cc.action.app_update')
    end

    def update(app, message)
      validate_not_changing_lifecycle_type!(app, message)

      app.db.transaction do
        app.lock!

        app.name                  = message.name if message.requested?(:name)
        app.environment_variables = message.environment_variables if message.requested?(:environment_variables)

        app.save

        update_lifecycle_data(app, message)

        Repositories::Runtime::AppEventRepository.new.record_app_update(
          app,
          app.space,
          @user.guid,
          @user_email,
          message.audit_hash
        )
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def validate_not_changing_lifecycle_type!(app, message)
      return unless message.requested?(:lifecycle)
      return if app.lifecycle_type == message.lifecycle_type

      raise InvalidApp.new('Lifecycle type cannot be changed')
    end

    def update_lifecycle_data(app, message)
      should_save = false
      if message.buildpack_data.requested?(:buildpack)
        should_save = true
        app.lifecycle_data.buildpack = message.buildpack_data.buildpack
      end
      if message.buildpack_data.requested?(:stack)
        should_save = true
        app.lifecycle_data.stack = message.buildpack_data.stack
      end
      app.lifecycle_data.save if should_save
    end
  end
end
