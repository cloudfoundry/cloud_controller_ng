require 'actions/process_scale'

module VCAP::CloudController
  class AppApplyManifest
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def apply(app_guid, message)
      app = AppModel.find(guid: app_guid)
      process_scale_message = message.process_scale_message
      ProcessScale.new(user_audit_info, app.web_process, process_scale_message).scale

      app
    end

    def logger
      @logger ||= Steno.logger('cc.action.app_apply_manifest')
    end

    attr_reader :user_audit_info
  end
end
