module VCAP::CloudController
  module Repositories
    class DropletEventRepository
      CENSORED_FIELDS   = [:environment_variables].freeze
      CENSORED_MESSAGE  = 'PRIVATE DATA HIDDEN'.freeze
      def self.record_create_by_staging(droplet, actor, actor_name, request_attrs, v3_app_name, space_guid, org_guid)
        Loggregator.emit(droplet.app_guid, "Creating droplet for app with guid #{droplet.app_guid}")

        metadata = {
          droplet_guid: droplet.guid,
          package_guid: droplet.package.guid,
          request:      droplet_audit_hash(request_attrs)
        }

        Event.create(
          type:              'audit.app.droplet.create',
          actor:             actor.guid,
          actor_type:        'user',
          actor_name:        actor_name,
          actee:             droplet.app_guid,
          actee_type:        'v3-app',
          actee_name:        v3_app_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          metadata,
          space_guid:        space_guid,
          organization_guid: org_guid
        )
      end

      def self.record_create_by_copying(new_droplet_guid, source_droplet_guid, actor_guid, actor_name, v3_app_guid, v3_app_name, space_guid, org_guid)
        Loggregator.emit(v3_app_guid, "Creating droplet for app with guid #{v3_app_guid}")

        metadata = {
          droplet_guid: new_droplet_guid,
          request:      {
            source_droplet_guid: source_droplet_guid
          }
        }

        Event.create(
          type:              'audit.app.droplet.create',
          actor:             actor_guid,
          actor_type:        'user',
          actor_name:        actor_name,
          actee:             v3_app_guid,
          actee_type:        'v3-app',
          actee_name:        v3_app_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          metadata,
          space_guid:        space_guid,
          organization_guid: org_guid
        )
      end

      def self.record_delete(droplet, actor_guid, actor_name, v3_app_name, space_guid, org_guid)
        Loggregator.emit(droplet.app_guid, "Deleting droplet for app with guid #{droplet.app_guid}")

        metadata = { droplet_guid: droplet.guid }

        Event.create(
          type:              'audit.app.droplet.delete',
          actor:             actor_guid,
          actor_type:        'user',
          actor_name:        actor_name,
          actee:             droplet.app_guid,
          actee_type:        'v3-app',
          actee_name:        v3_app_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          metadata,
          space_guid:        space_guid,
          organization_guid: org_guid
        )
      end

      # Emit this event once we have droplet download capability
      def self.record_download(droplet, actor, actor_name, v3_app_name, space_guid, org_guid)
        Loggregator.emit(droplet.app_guid, "Downloading droplet for app with guid #{droplet.app_guid}")

        metadata = { droplet_guid: droplet.guid }

        Event.create(
          type:              'audit.app.droplet.download',
          actor:             actor.guid,
          actor_type:        'user',
          actor_name:        actor_name,
          actee:             droplet.app_guid,
          actee_type:        'v3-app',
          actee_name:        v3_app_name,
          timestamp:         Sequel::CURRENT_TIMESTAMP,
          metadata:          metadata,
          space_guid:        space_guid,
          organization_guid: org_guid
        )
      end

      def self.droplet_audit_hash(request_attrs)
        request_attrs.dup.tap do |attr|
          CENSORED_FIELDS.map(&:to_s).each do |censored|
            attr[censored] = CENSORED_MESSAGE if attr.key?(censored)
          end
        end
      end
    end
  end
end
