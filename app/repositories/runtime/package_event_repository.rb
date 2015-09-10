module VCAP::CloudController
  module Repositories
    module Runtime
      class PackageEventRepository
        def self.record_app_add_package(package, actor, actor_name, request_attrs)
          Loggregator.emit(package.app.guid, "Adding app package for app with guid #{package.app.guid}")

          metadata = { request: request_attrs }

          Event.create(
            space: package.space,
            type: 'audit.app.add_package',
            timestamp: Sequel::CURRENT_TIMESTAMP,
            actee: package.guid,
            actee_type: 'package',
            actee_name: '',
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
