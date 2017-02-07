module VCAP::CloudController
  class AppStop
    class InvalidApp < StandardError; end

    class << self
      def stop(app:, user_audit_info:, record_event: true)
        app.db.transaction do
          app.lock!
          app.update(desired_state: 'STOPPED')
          app.processes.each { |process| process.update(state: 'STOPPED') }

          record_audit_event(app, user_audit_info) if record_event
        end
      rescue Sequel::ValidationFailed => e
        raise InvalidApp.new(e.message)
      end

      def stop_without_event(app)
        stop(app: app, user_audit_info: nil, record_event: false)
      end

      private

      def record_audit_event(app, user_audit_info)
        Repositories::AppEventRepository.new.record_app_stop(
          app,
          user_audit_info,
        )
      end
    end
  end
end
