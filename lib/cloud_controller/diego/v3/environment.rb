module VCAP::CloudController
  module Diego
    module V3
      class Environment
        def initialize(app, space, initial_env={})
          @app         = app
          @space       = space
          @initial_env = initial_env || {}
        end

        def build(additional_variables={})
          app_env = @app.environment_variables || {}

          @initial_env.
            merge(app_env).
            merge(additional_variables.try(:stringify_keys)).
            merge({
              'VCAP_APPLICATION' => vcap_application,
              'MEMORY_LIMIT'     => default_memory_limit,
              'VCAP_SERVICES'    => {}
            })
        end

        private

        def vcap_application
          version = SecureRandom.uuid
          uris = @app.routes.map(&:fqdn)

          {
            'limits'              => {
              'mem'  => default_memory_limit,
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

        def default_memory_limit
          Config.config[:default_app_memory]
        end

        def default_disk_limit
          Config.config[:default_app_disk_in_mb]
        end

        def self.hash_to_diego_env(hash)
          hash.map do |k, v|
            case v
            when Array, Hash
              v = MultiJson.dump(v)
            else
              v = v.to_s
            end

            { 'name' => k, 'value' => v }
          end
        end
      end
    end
  end
end
