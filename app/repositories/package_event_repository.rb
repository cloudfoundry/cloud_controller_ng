require 'repositories/event_types'

module VCAP::CloudController
  module Repositories
    class PackageEventRepository
      def self.record_app_package_create(package, user_audit_info, request_attrs)
        app_guid = request_attrs.delete('app_guid')
        VCAP::AppLogEmitter.emit(app_guid, "Adding app package for app with guid #{app_guid}")

        metadata = {
          package_guid: package.guid,
          request: request_attrs
        }

        create_event(package, EventTypes::APP_PACKAGE_CREATE, user_audit_info, metadata)
      end

      def self.record_app_package_copy(package, user_audit_info, source_package_guid)
        app = package.app
        VCAP::AppLogEmitter.emit(app.guid, "Adding app package for app with guid #{app.guid} copied from package with guid #{source_package_guid}")
        metadata = {
          package_guid: package.guid,
          request: {
            source_package_guid:
          }
        }
        type = EventTypes::APP_PACKAGE_CREATE

        create_event(package, type, user_audit_info, metadata)
      end

      def self.record_app_package_upload(package, user_audit_info)
        VCAP::AppLogEmitter.emit(package.app_guid, "Uploading app package for app with guid #{package.app_guid}")
        metadata = { package_guid: package.guid }

        create_event(package, EventTypes::APP_PACKAGE_UPLOAD, user_audit_info, metadata)
      end

      def self.record_app_upload_bits(package, user_audit_info)
        VCAP::AppLogEmitter.emit(package.app_guid, "Uploading bits for app with guid #{package.app_guid}")
        metadata = { package_guid: package.guid }

        create_event(package, EventTypes::APP_UPLOAD_BITS, user_audit_info, metadata)
      end

      def self.record_app_package_delete(package, user_audit_info)
        VCAP::AppLogEmitter.emit(package.app_guid, "Deleting app package for app with guid #{package.app_guid}")
        metadata = { package_guid: package.guid }

        create_event(package, EventTypes::APP_PACKAGE_DELETE, user_audit_info, metadata)
      end

      def self.record_app_package_download(package, user_audit_info)
        VCAP::AppLogEmitter.emit(package.app_guid, "Downloading app package for app with guid #{package.app_guid}")
        metadata = { package_guid: package.guid }

        create_event(package, EventTypes::APP_PACKAGE_DOWNLOAD, user_audit_info, metadata)
      end

      def self.create_event(package, type, user_audit_info, metadata)
        app = package.app
        Event.create(
          space: package.space,
          type: type,
          timestamp: Sequel::CURRENT_TIMESTAMP,
          actee: app.guid,
          actee_type: 'app',
          actee_name: app.name,
          actor: user_audit_info.user_guid,
          actor_type: 'user',
          actor_name: user_audit_info.user_email,
          actor_username: user_audit_info.user_name,
          metadata: metadata
        )
      end
    end
  end
end
