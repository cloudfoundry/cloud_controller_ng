module VCAP::CloudController
  class AppUpdate
    class DropletNotFound < StandardError; end
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user = user
      @user_email = user_email
      @logger = Steno.logger('cc.action.app_update')
    end

    def update(app, message)
      app.db.transaction do
        app.lock!

        if message['name']
          app.name = message['name']
        end

        if message['environment_variables']
          app.environment_variables = message['environment_variables']
        end

        app.save

        Repositories::Runtime::AppEventRepository.new.record_app_update(
          app,
          app.space,
          @user.guid,
          @user_email,
          message
        )
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
