module VCAP::CloudController
  module Diego
    class Environment
      EXCLUDE = [:application_uris, :uris, :users]

      def initialize(app, initial_env={})
        @app = app
        @initial_env = initial_env || {}
      end

      def as_json(_={})
        env = []
        env << { 'name' => 'VCAP_APPLICATION', 'value' => vcap_application.to_json }
        env << { 'name' => 'VCAP_SERVICES', 'value' => app.system_env_json['VCAP_SERVICES'].to_json }
        env << { 'name' => 'MEMORY_LIMIT', 'value' => "#{app.memory}m" }
        env << { 'name' => 'CF_STACK', 'value' => "#{app.stack.name}" }

        db_uri = app.database_uri
        env << { 'name' => 'DATABASE_URL', 'value' => db_uri } if db_uri

        app_env_json = app.environment_json || {}
        add_hash_to_env(app_env_json, env)
        add_hash_to_env(@initial_env, env)

        env
      end

      private

      attr_reader :app

      def vcap_application
        env = app.vcap_application
        EXCLUDE.each { |k| env.delete(k) }
        env
      end

      def add_hash_to_env(hash, env)
        hash.each do |k, v|
          case v
          when Array, Hash
            v = MultiJson.dump(v)
          else
            v = v.to_s
          end

          env << { 'name' => k, 'value' => v }
        end
      end
    end
  end
end
