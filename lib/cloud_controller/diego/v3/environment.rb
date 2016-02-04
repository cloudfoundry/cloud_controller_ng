module VCAP::CloudController
  module Diego
    module V3
      class Environment
        def initialize(app, task, space, initial_env={})
          @app         = app
          @task        = task
          @space       = space
          @initial_env = initial_env || {}
        end

        def build(additional_variables={})
          app_env = @app.environment_variables || {}
          additional_variables ||= {}

          @initial_env.
            merge(app_env).
            merge(additional_variables.try(:stringify_keys)).
            merge({
              'VCAP_APPLICATION' => vcap_application,
              'MEMORY_LIMIT'     => @task.memory_in_mb,
              'VCAP_SERVICES'    => {}
            })
        end

        private

        def vcap_application
          version = SecureRandom.uuid
          uris = @app.routes.map(&:fqdn)

          {
            'limits'              => {
              'mem'  => @task.memory_in_mb,
              'disk' => default_disk_limit,
              'fds'  => Config.config[:instance_file_descriptor_limit] || 16384,
            },
            'application_id'      => @app.guid,
            'application_version' => version,
            'application_name'    => @app.name,
            'application_uris'    => uris,
            'version'             => version,
            'name'                => @app.name,
            'space_name'          => @space.name,
            'space_id'            => @space.guid,
            'uris'                => uris,
            'users'               => nil
          }
        end

        def default_disk_limit
          Config.config[:default_app_disk_in_mb]
        end
      end
    end
  end
end
