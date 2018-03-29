require 'actions/process_scale'
require 'cloud_controller/strategies/manifest_strategy'

module VCAP::CloudController
  class AppApplyManifest
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def apply(app_guid, message)
      app = AppModel.find(guid: app_guid)
      ProcessScale.new(user_audit_info, app.web_process, message.process_scale_message).scale

      app_update_message = message.app_update_message
      lifecycle = AppLifecycleProvider.provide_for_update(app_update_message, app)
      AppUpdate.new(user_audit_info).update(app, app_update_message, lifecycle)

      ProcessUpdate.new(user_audit_info).update(app.web_process, message.manifest_process_update_message, ManifestStrategy)

      AppPatchEnvironmentVariables.new(user_audit_info).patch(app, message.app_update_environment_variables_message)

      app
    end

    def logger
      @logger ||= Steno.logger('cc.action.app_apply_manifest')
    end

    attr_reader :user_audit_info
  end
end
