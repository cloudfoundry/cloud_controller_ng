module VCAP::CloudController
  class AppCreate
    class InvalidApp < StandardError; end

    def initialize(user, user_email)
      @user       = user
      @user_email = user_email
      @logger     = Steno.logger('cc.action.app_create')
    end

    def create(message, lifecycle)
      app = nil
      AppModel.db.transaction do
        app = AppModel.create(
          name:                  message.name,
          space_guid:            message.space_guid,
          environment_variables: message.environment_variables,
        )

        lifecycle.create_lifecycle_data_model(app)

        Repositories::Runtime::AppEventRepository.new.record_app_create(
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
  end
end
