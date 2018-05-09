module VCAP::CloudController
  module Presenters
    module V3
      class AppManifestPresenter
        def initialize(app, service_bindings, routes)
          @app = app
          @service_bindings = service_bindings
          @routes = routes
        end

        def to_hash
          {
            applications: [
              {
                name: app.name,
                env: app.environment_variables.presence,
              }.
                merge(lifecycle_properties).
                merge(services_properties).
                merge(routes_properties).
                merge(processes_properties).
                compact
            ]
          }
        end

        private

        attr_reader :app, :service_bindings, :routes

        def services_properties
          service_instance_names = service_bindings.map(&:service_instance_name)
          { services: alphabetize(service_instance_names).presence, }
        end

        def routes_properties
          route_hashes = alphabetize(routes.map(&:uri)).map { |uri| { route: uri } }
          { routes: route_hashes.presence, }
        end

        def lifecycle_properties
          app.docker? ? docker_lifecycle_properties : buildpack_lifecycle_properties
        end

        def buildpack_lifecycle_properties
          {
            buildpacks: app.lifecycle_data.buildpacks.presence,
            stack: app.lifecycle_data.stack,
          }
        end

        def docker_lifecycle_properties
          return {} unless app.current_package
          {
            docker: {
              image: app.current_package.image,
              username: app.current_package.docker_username
            }.compact
          }
        end

        def processes_properties
          processes = app.processes.sort_by(&:type).map { |process| process_hash(process) }
          { processes: processes.presence }
        end

        def process_hash(process)
          {
            'type' => process.type,
            'instances' => process.instances,
            'memory' => process.memory,
            'disk_quota' => process.disk_quota,
            'command' => process.command,
            'health-check-type' => process.health_check_type,
            'health-check-http-endpoint' => process.health_check_http_endpoint,
            'timeout' => process.health_check_timeout,
          }.compact
        end

        def alphabetize(array)
          array.sort_by(&:downcase)
        end
      end
    end
  end
end
