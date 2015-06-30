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
      app.db.transaction do
        app.lock!

        app.name                  = message.name if message.requested?(:name)
        app.environment_variables = message.environment_variables if message.requested?(:environment_variables)
        app.buildpack             = message.buildpack if message.requested?(:buildpack)

        app.save

        Repositories::Runtime::AppEventRepository.new.record_app_update(
          app,
          app.space,
          @user.guid,
          @user_email,
          message.as_json({ only: (message.requested_keys).map(&:to_s) })
        )
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
