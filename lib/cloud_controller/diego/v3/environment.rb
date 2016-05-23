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

          vars_builder = VCAP::VarsBuilder.new(
            @app,
            memory_limit: @task.memory_in_mb,
            staging_disk_in_mb: default_disk_limit,
            space: @space,
            file_descriptors: Config.config[:instance_file_descriptor_limit] || 16384,
            version: SecureRandom.uuid
          )
          vcap_application = vars_builder.to_hash

          @initial_env.
            merge(app_env).
            merge(additional_variables.try(:stringify_keys)).
            merge({
              'VCAP_APPLICATION' => vcap_application,
              'MEMORY_LIMIT'     => "#{@task.memory_in_mb}m"
            }).
            merge(SystemEnvPresenter.new(@app.service_bindings).system_env.stringify_keys)
        end

        private

        def default_disk_limit
          Config.config[:default_app_disk_in_mb]
        end
      end
    end
  end
end
