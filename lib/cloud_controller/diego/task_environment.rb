require 'credhub/config_helpers'

module VCAP::CloudController
  module Diego
    class TaskEnvironment
      include ::Credhub::ConfigHelpers

      def initialize(app, task, space, initial_envs={})
        @app          = app
        @task         = task
        @space        = space
        @initial_envs = initial_envs || {}
      end

      def build
        app_env = app.environment_variables || {}

        task_env =
          initial_envs.
          merge(app_env).
          merge('VCAP_APPLICATION' => vcap_application, 'MEMORY_LIMIT' => "#{task.memory_in_mb}m").
          merge(SystemEnvPresenter.new(app).system_env.stringify_keys)

        task_env = task_env.merge('VCAP_PLATFORM_OPTIONS' => credhub_url) if credhub_url.present? && cred_interpolation_enabled?

        task_env = task_env.merge('LANG' => DEFAULT_LANG) if [BuildpackLifecycleDataModel::LIFECYCLE_TYPE, CNBLifecycleDataModel::LIFECYCLE_TYPE].include?(app.lifecycle_type)
        task_env = task_env.merge('DATABASE_URL' => app.database_uri) if app.database_uri

        task_env
      end

      attr_reader :app, :task, :space, :initial_envs

      private

      def vcap_application
        vars_builder = VCAP::VarsBuilder.new(
          app,
          memory_limit: task.memory_in_mb,
          staging_disk_in_mb: default_disk_limit,
          space: space,
          file_descriptors: Config.config.get(:instance_file_descriptor_limit),
          version: SecureRandom.uuid
        )

        vars_builder.to_hash
      end

      def default_disk_limit
        Config.config.get(:default_app_disk_in_mb)
      end
    end
  end
end
