require 'models/helpers/label_helpers'

module VCAP::CloudController
  class AppUpdate
    class DropletNotFound < StandardError; end
    class InvalidApp < StandardError; end

    def initialize(user_audit_info, manifest_triggered: false)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.app_update')
      @manifest_triggered = manifest_triggered
    end

    def update(app, message, lifecycle)
      validate_not_changing_lifecycle_type!(app, lifecycle)

      app.db.transaction do
        app.lock!

        app.name = message.name if message.requested?(:name)

        update_app_command(app, message) if message.requested?(:command)
        update_app_env(app, message) if message.requested?(:env)
        update_app_labels(app, message) if message.requested?(:metadata)

        app.save

        raise InvalidApp.new(lifecycle.errors.full_messages.join(', ')) unless lifecycle.valid?
        lifecycle.update_lifecycle_data_model(app)

        raise CloudController::Errors::ApiError.new_from_details('CustomBuildpacksDisabled') if using_disabled_custom_buildpack?(app)

        Repositories::AppEventRepository.new.record_app_update(
          app,
          app.space,
          @user_audit_info,
          message.audit_hash,
          manifest_triggered: @manifest_triggered
        )
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end

    private

    def update_app_command(app, message)
      app.web_process.command = message.command
      app.web_process.save
    end

    def update_app_env(app, message)
      app.environment_variables = existing_environment_variables_for(app).merge(message.env).compact
    end

    def update_app_labels(app, message)
      labels = message.labels || {}
      labels.each do |full_key, value|
        full_key = full_key.to_s
        prefix, key = VCAP::CloudController::LabelHelpers.extract_prefix(full_key)
        app_label = AppLabelModel.find_or_create(app_guid: app.guid, prefix: prefix, key: key)
        app_label.update(value: value.to_s)
      end
    end

    def using_disabled_custom_buildpack?(app)
      app.lifecycle_data.using_custom_buildpack? && custom_buildpacks_disabled?
    end

    def custom_buildpacks_disabled?
      VCAP::CloudController::Config.config.get(:disable_custom_buildpacks)
    end

    def validate_not_changing_lifecycle_type!(app, lifecycle)
      return if app.lifecycle_type == lifecycle.type
      raise InvalidApp.new('Lifecycle type cannot be changed')
    end

    def existing_environment_variables_for(app)
      app.environment_variables.nil? ? {} : app.environment_variables.symbolize_keys
    end
  end
end
