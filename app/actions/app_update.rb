module VCAP::CloudController
  class AppUpdate
    class DropletNotFound < StandardError; end
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
      @logger     = Steno.logger('cc.action.app_update')
    end

    def update(app, message, lifecycle)
      validate_not_changing_lifecycle_type!(app, lifecycle)

      app.db.transaction do
        app.lock!

        app.name                  = message.name if message.requested?(:name)
        app.environment_variables = message.environment_variables if message.requested?(:environment_variables)

        app.save

        lifecycle.update_lifecycle_data_model(app)

        Repositories::AppEventRepository.new.record_app_update(
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

    def validate_not_changing_lifecycle_type!(app, lifecycle)
      return if app.lifecycle_type == lifecycle.type
      raise InvalidApp.new('Lifecycle type cannot be changed')
    end
  end
end
