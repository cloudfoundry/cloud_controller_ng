require 'actions/process_scale'

module VCAP::CloudController
  class AppApplyManifest
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def apply(app_guid, message)
      app = AppModel.find(guid: app_guid)
      ProcessScale.new(user_audit_info, app.web_process, message).scale

      app
    end

    def logger
      @logger ||= Steno.logger('cc.action.app_apply_manifest')
    end

    attr_reader :user_audit_info
  end
end
