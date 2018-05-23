module VCAP::CloudController
  class AppCreate
    class InvalidApp < StandardError; end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.app_create')
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

        raise CloudController::Errors::ApiError.new_from_details('CustomBuildpacksDisabled') if using_disabled_custom_buildpack?(app)

        Repositories::AppEventRepository.new.record_app_create(
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

    private

    def using_disabled_custom_buildpack?(app)
      app.lifecycle_data.using_custom_buildpack? && custom_buildpacks_disabled?
    end

    def custom_buildpacks_disabled?
      VCAP::CloudController::Config.config.get(:disable_custom_buildpacks)
    end
  end
end
