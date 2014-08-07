module VCAP::CloudController
  module Diego
    class Environment
      def initialize(app)
        @app = app
      end

      def as_json(_={})
        env = []
        env << {"name" => "VCAP_APPLICATION", "value" => app.vcap_application.to_json}
        env << {"name" => "VCAP_SERVICES", "value" => app.system_env_json["VCAP_SERVICES"].to_json}
        env << {"name" => "MEMORY_LIMIT", "value" => "#{app.memory}m"}

        db_uri = app.database_uri
        env << {"name" => "DATABASE_URL", "value" => db_uri} if db_uri

        app_env_json = app.environment_json || {}
        app_env_json.each do |k, v|
          env << {"name" => k, "value" => v}
        end

        env
      end

      private

      attr_reader :app
    end
  end
end
