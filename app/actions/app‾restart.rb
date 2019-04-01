require 'actions/process_restart'
require 'actions/revision_resolver'

module VCAP::CloudController
  class AppRestart
    class Error < StandardError
    end

    class << self
      def restart(app:, config:, user_audit_info:)
        need_to_stop_in_runtime = !app.stopped?

        app.db.transaction do
          app.lock!
          RevisionResolver.update_app_revision(app, user_audit_info)
          app.update(desired_state: ProcessModel::STARTED)
          app.processes.each do |process|
            ProcessRestart.restart(
              process: process,
              config: config,
              revision: app.latest_revision,
              stop_in_runtime: need_to_stop_in_runtime,
            )
          end
          record_audit_event(app, user_audit_info)
        end
      rescue Sequel::ValidationFailed => e
        raise Error.new(e.message)
      end

      private

      def record_audit_event(app, user_audit_info)
        Repositories::AppEventRepository.new.record_app_restart(
          app,
          user_audit_info,
        )
      end
    end
  end
end
