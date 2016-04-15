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
          type = 'audit.app.package.create'

          self.create_event(package, type, actor, actor_name, metadata)
        end

        def self.record_app_package_copy(package, actor, actor_name, source_package_guid)
          app = package.app
          Loggregator.emit(app.guid, "Adding app package for app with guid #{app.guid} copied from package with guid #{source_package_guid}")
          metadata = {
            package_guid: package.guid,
            request: {
              source_package_guid: source_package_guid
            }
          }
          type = 'audit.app.package.create'

          create_event(package, type, actor, actor_name, metadata)
        end

        def self.record_app_package_upload(package, actor, actor_name)
          Loggregator.emit(package.app.guid, "Uploading app package for app with guid #{package.app.guid}")
          metadata = { package_guid: package.guid }
          type = 'audit.app.package.upload'

          create_event(package, type, actor, actor_name, metadata)
        end

        def self.create_event(package, type, actor, actor_name, metadata)
          app = package.app
          Event.create(
            space: package.space,
            type: type,
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
