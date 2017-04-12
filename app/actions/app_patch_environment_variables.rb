module VCAP::CloudController
  class AppPatchEnvironmentVariables
    class InvalidApp < StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger          = Steno.logger('cc.action.app_update_environment_variables')
    end

    def patch(app, message)
      app.db.transaction do
        app.lock!

        if message.requested?(:environment_variables)
          new_values                     = message.environment_variables
          existing_environment_variables = app.environment_variables.symbolize_keys
          app.environment_variables      = existing_environment_variables.merge(new_values).reject { |_, v| v.nil? }
          app.save
        end

        Repositories::AppEventRepository.new.record_app_update(
          app,
          app.space,
          @user_audit_info,
          message.audit_hash
        )
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
