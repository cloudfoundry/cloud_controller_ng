require 'process_create'
require 'models/helpers/process_types'
require 'actions/labels_update'
require 'cloud_controller/errors/api_error_helpers'

module VCAP::CloudController
  class AppCreate
    include CloudController::Errors::ApiErrorHelpers

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
        validate_buildpacks_are_ready(app)

        MetadataUpdate.update(app, message)

        api_error!(:CustomBuildpacksDisabled) if using_disabled_custom_buildpack?(app)

        ProcessCreate.new(@user_audit_info).create(app, {
          guid: app.guid,
          type: ProcessTypes::WEB,
        })

        Repositories::AppEventRepository.new.record_app_create(
          app,
          app.space,
          @user_audit_info,
          message.audit_hash
        )
      end

      app
    rescue Sequel::ValidationFailed => e
      if e.errors.on([:space_guid, :name])
        v3_api_error!(:UniquenessError, e.message)
      end

      raise InvalidApp.new(e.message)
    end

    private

    def using_disabled_custom_buildpack?(app)
      app.lifecycle_data.using_custom_buildpack? && custom_buildpacks_disabled?
    end

    def custom_buildpacks_disabled?
      VCAP::CloudController::Config.config.get(:disable_custom_buildpacks)
    end

    def validate_buildpacks_are_ready(app)
      return unless app.buildpack_lifecycle_data

      app.buildpack_lifecycle_data.buildpack_lifecycle_buildpacks.each do |blb|
        unless blb.custom?
          buildpack = Buildpack.find(name: blb.admin_buildpack_name)

          if buildpack && buildpack.state != Buildpack::READY_STATE
            raise InvalidApp.new("#{buildpack.name.inspect} must be in ready state")
            # errors.add(:buildpack, "#{buildpack.name.inspect} must be in ready state")
          end
        end
      end
    end
  end
end
