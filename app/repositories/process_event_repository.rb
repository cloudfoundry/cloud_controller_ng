module VCAP::CloudController
  module Repositories
    class ProcessEventRepository
      CENSORED_MESSAGE = 'PRIVATE DATA HIDDEN'.freeze

      def self.record_create(process, user_guid, user_name)
        Loggregator.emit(process.app.guid, "Added process: \"#{process.type}\"")

        create_event(
          process:    process,
          type:       'audit.app.process.create',
          actor_guid: user_guid,
          actor_name: user_name,
          metadata:   {
            process_guid: process.guid,
            process_type: process.type
          }
        )
      end

      def self.record_delete(process, user_guid, user_name)
        Loggregator.emit(process.app.guid, "Deleting process: \"#{process.type}\"")

        create_event(
          process:    process,
          type:       'audit.app.process.delete',
          actor_guid: user_guid,
          actor_name: user_name,
          metadata:   {
            process_guid: process.guid,
            process_type: process.type
          }
        )
      end

      def self.record_update(process, user_guid, user_name, request)
        Loggregator.emit(process.app.guid, "Updating process: \"#{process.type}\"")

        request           = request.dup.symbolize_keys
        request[:command] = CENSORED_MESSAGE if request.key?(:command)

        create_event(
          process:    process,
          type:       'audit.app.process.update',
          actor_guid: user_guid,
          actor_name: user_name,
          metadata:   {
            process_guid: process.guid,
            process_type: process.type,
            request:      request
          }
        )
      end

      def self.record_scale(process, user_guid, user_name, request)
        Loggregator.emit(process.app.guid, "Scaling process: \"#{process.type}\"")

        create_event(
          process:    process,
          type:       'audit.app.process.scale',
          actor_guid: user_guid,
          actor_name: user_name,
          metadata:   {
            process_guid: process.guid,
            process_type: process.type,
            request:      request
          }
        )
      end

      def self.record_terminate(process, user_guid, user_name, index)
        Loggregator.emit(process.app.guid, "Terminating process: \"#{process.type}\", index: \"#{index}\"")

        create_event(
          process:    process,
          type:       'audit.app.process.terminate_instance',
          actor_guid: user_guid,
          actor_name: user_name,
          metadata:   {
            process_guid:  process.guid,
            process_type:  process.type,
            process_index: index
          }
        )
      end

      def self.record_crash(process, crash_payload)
        Loggregator.emit(process.app.guid, "Process has crashed with type: \"#{process.type}\"")

        create_event(
          process:    process,
          type:       'audit.app.process.crash',
          actor_guid: process.guid,
          actor_name: process.type,
          actor_type: 'v3-process',
          metadata:   crash_payload
        )
      end

      class << self
        private

        def create_event(process:, type:, actor_guid:, actor_name:, metadata:, actor_type: 'user')
          app = process.app
          Event.create(
            type:       type,
            actee:      app.guid,
            actee_type: 'v3-app',
            actee_name: app.name,
            actor:      actor_guid,
            actor_type: actor_type,
            actor_name: actor_name,
            timestamp:  Sequel::CURRENT_TIMESTAMP,
            space:      process.space,
            metadata:   metadata
          )
        end
      end
    end
  end
end
