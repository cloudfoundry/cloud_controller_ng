module VCAP::CloudController
  module Repositories
    module Runtime
      class PackageEventRepository
        def self.record_app_package_create(package, actor, actor_name, request_attrs)
          app_guid = request_attrs.delete('app_guid')
          Loggregator.emit(app_guid, "Adding app package for app with guid #{app_guid}")

          metadata = {
            package_guid: package.guid,
            request: request_attrs
          }

          Event.create(
            space: package.space,
            type: 'audit.app.package.create',
            timestamp: Sequel::CURRENT_TIMESTAMP,
            actee: app_guid,
            actee_type: 'v3-app',
            actee_name: package.app.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            metadata: metadata
          )
        end

        def self.record_app_package_copy(package, actor, actor_name, source_package_guid)
          app = package.app
          metadata = {
            package_guid: package.guid,
            request: {
              source_package_guid: source_package_guid
            }
          }

          Event.create(
            space: package.space,
            type: 'audit.app.package.create',
            timestamp: Sequel::CURRENT_TIMESTAMP,
            actee: app.guid,
            actee_type: 'v3-app',
            actee_name: app.name,
            actor: actor.guid,
            actor_type: 'user',
            actor_name: actor_name,
            metadata: metadata
          )
        end
      end
    end
  end
end
