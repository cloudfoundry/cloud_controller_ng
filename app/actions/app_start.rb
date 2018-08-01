require 'actions/current_process_types'

module VCAP::CloudController
  class AppStart
    class InvalidApp < StandardError; end

    class << self
      def start(app:, user_guid:, user_email:, record_event: true)
        app.db.transaction do
          app.lock!
          app.update(desired_state: 'STARTED')
          app.processes.each { |process| process.update(state: 'STARTED') }

          record_audit_event(app, user_guid, user_email) if record_event
        end
      rescue Sequel::ValidationFailed => e
        raise InvalidApp.new(e.message)
      end

      def start_without_event(app)
        start(app: app, user_guid: nil, user_email: nil, record_event: false)
      end

      private

      def record_audit_event(app, user_guid, user_email)
        Repositories::AppEventRepository.new.record_app_start(
          app,
          user_guid,
          user_email
        )
      end
    end
  end
end
