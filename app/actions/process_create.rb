require 'repositories/process_event_repository'

module VCAP::CloudController
  class ProcessCreate
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def create(app, message)
      attrs = message.merge({
        diego:             true,
        instances:         message[:type] == 'web' ? 1 : 0,
        health_check_type: message[:type] == 'web' ? 'port' : 'process',
        metadata:          {},
      })
      attrs[:guid] = app.guid if message[:type] == 'web'

      process = nil
      app.class.db.transaction do
        process = app.add_process(attrs)
        Repositories::ProcessEventRepository.record_create(process, @user_audit_info)
      end

      process
    end
  end
end
