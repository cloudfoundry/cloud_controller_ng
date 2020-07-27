require 'models/helpers/metadata_helpers'
require 'actions/labels_update'
require 'actions/annotations_update'

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

        LabelsUpdate.update(app, message.labels, AppLabelModel)
        AnnotationsUpdate.update(app, message.annotations, AppAnnotationModel)

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

    def using_disabled_custom_buildpack?(app)
      app.lifecycle_data.using_custom_buildpack? && custom_buildpacks_disabled?
    end

    def custom_buildpacks_disabled?
      VCAP::CloudController::Config.config.get(:disable_custom_buildpacks)
    end

    def validate_not_changing_lifecycle_type!(app, lifecycle)
      return if app.lifecycle_type == lifecycle.type

      raise InvalidApp.new("Lifecycle type cannot be changed from #{app.lifecycle_type} to #{lifecycle.type}")
    end

    def existing_environment_variables_for(app)
      app.environment_variables.nil? ? {} : app.environment_variables.symbolize_keys
    end
  end
end
