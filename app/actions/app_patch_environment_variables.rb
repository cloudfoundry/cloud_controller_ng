module VCAP::CloudController
  class AppPatchEnvironmentVariables
    class InvalidApp < StandardError
    end

    def initialize(user_audit_info, manifest_triggered: false)
      @user_audit_info = user_audit_info
      @logger          = Steno.logger('cc.action.app_update_environment_variables')
      @manifest_triggered = manifest_triggered
    end

    def patch(app, message)
      app.db.transaction do
        app.lock!

        if message.requested?(:var)
          new_values                     = message.var
          app.environment_variables      = existing_environment_variables_for(app).merge(new_values).compact
          app.save
        end

        Repositories::AppEventRepository.new.record_app_update(
          app,
          app.space,
          @user_audit_info,
          message.audit_hash,
          manifest_triggered: @manifest_triggered,
        )
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def existing_environment_variables_for(app)
      app.environment_variables.nil? ? {} : app.environment_variables.symbolize_keys
    end
  end
end
