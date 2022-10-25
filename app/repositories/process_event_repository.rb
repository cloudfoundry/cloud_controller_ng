require 'repositories/mixins/app_manifest_event_mixins'
require 'repositories/mixins/truncation_mixin'

module VCAP::CloudController
  module Repositories
    class ProcessEventRepository
      extend AppManifestEventMixins
      extend TruncationMixin

      def self.record_create(process, user_audit_info, manifest_triggered: false)
        VCAP::AppLogEmitter.emit(process.app_guid, "Added process: \"#{process.type}\"")

        metadata = add_manifest_triggered(manifest_triggered, {
          process_guid: process.guid,
          process_type: process.type,
        })

        create_event(
          process:        process,
          type:           'audit.app.process.create',
          actor_guid:     user_audit_info.user_guid,
          actor_name:     user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          metadata: metadata
        )
      end

      def self.record_delete(process, user_audit_info)
        VCAP::AppLogEmitter.emit(process.app_guid, "Deleting process: \"#{process.type}\"")

        create_event(
          process:        process,
          type:           'audit.app.process.delete',
          actor_guid:     user_audit_info.user_guid,
          actor_name:     user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          metadata:       {
            process_guid: process.guid,
            process_type: process.type
          }
        )
      end

      def self.record_update(process, user_audit_info, request, manifest_triggered: false)
        VCAP::AppLogEmitter.emit(process.app_guid, "Updating process: \"#{process.type}\"")

        request           = request.dup.symbolize_keys
        request[:command] = Presenters::Censorship::PRIVATE_DATA_HIDDEN if request.key?(:command)
        metadata = add_manifest_triggered(manifest_triggered, {
          process_guid: process.guid,
          process_type: process.type,
          request: request
        })

        create_event(
          process:        process,
          type:           'audit.app.process.update',
          actor_guid:     user_audit_info.user_guid,
          actor_name:     user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          metadata: metadata
        )
      end

      def self.record_scale(process, user_audit_info, request, manifest_triggered: false)
        VCAP::AppLogEmitter.emit(process.app_guid, "Scaling process: \"#{process.type}\"")

        metadata = add_manifest_triggered(manifest_triggered, {
          process_guid: process.guid,
          process_type: process.type,
          request: request,
        })

        create_event(
          process:        process,
          type:           'audit.app.process.scale',
          actor_guid:     user_audit_info.user_guid,
          actor_name:     user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          metadata: metadata
        )
      end

      def self.record_terminate(process, user_audit_info, index)
        VCAP::AppLogEmitter.emit(process.app_guid, "Terminating process: \"#{process.type}\", index: \"#{index}\"")

        create_event(
          process:        process,
          type:           'audit.app.process.terminate_instance',
          actor_guid:     user_audit_info.user_guid,
          actor_name:     user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          metadata:       {
            process_guid:  process.guid,
            process_type:  process.type,
            process_index: index
          }
        )
      end

      def self.record_crash(process, crash_payload)
        VCAP::AppLogEmitter.emit(process.app_guid, "Process has crashed with type: \"#{process.type}\"")
        crash_payload['exit_description'] = truncate(crash_payload['exit_description'])

        create_event(
          process:    process,
          type:       'audit.app.process.crash',
          actor_guid: process.guid,
          actor_name: process.type,
          actor_type: 'process',
          metadata:   crash_payload
        )
      end

      def self.record_rescheduling(process, rescheduling_payload)
        VCAP::AppLogEmitter.emit(process.app_guid, 'Process is being rescheduled')

        create_event(
          process:    process,
          type:       'audit.app.process.rescheduling',
          actor_guid: process.guid,
          actor_name: process.type,
          actor_type: 'process',
          metadata:   rescheduling_payload
        )
      end

      class << self
        private

        def create_event(process:, type:, actor_guid:, actor_name:, metadata:, actor_username: '', actor_type: 'user')
          app = process.app
          Event.create(
            type:           type,
            actee:          app.guid,
            actee_type:     'app',
            actee_name:     app.name,
            actor:          actor_guid,
            actor_type:     actor_type,
            actor_name:     actor_name,
            actor_username: actor_username,
            timestamp:      Sequel::CURRENT_TIMESTAMP,
            space:          process.space,
            metadata:       metadata
          )
        end
      end
    end
  end
end
