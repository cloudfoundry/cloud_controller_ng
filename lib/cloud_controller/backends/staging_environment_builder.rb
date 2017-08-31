require_relative '../../vcap/vars_builder'

module VCAP::CloudController
  class StagingEnvironmentBuilder
    def build(app, space, lifecycle, memory_limit, staging_disk_in_mb, vars_from_message=nil)
      app_env = app.environment_variables || {}
      vars_from_message ||= {}
      staging_var_group = EnvironmentVariableGroup.staging.environment_json

      vars_builder = VCAP::VarsBuilder.new(
        app,
        memory_limit: memory_limit,
        staging_disk_in_mb: staging_disk_in_mb,
        space: space,
        file_descriptors: Config.config.get(:instance_file_descriptor_limit) || 16384,
        version: SecureRandom.uuid
      )
      vcap_application = vars_builder.to_hash

      staging_var_group.
        merge(app_env).
        merge(vars_from_message.try(:stringify_keys)).
        merge(lifecycle.staging_environment_variables).
        merge(
          {
            'VCAP_APPLICATION' => vcap_application,
            'MEMORY_LIMIT'     => "#{memory_limit}m"
          }).
        merge(SystemEnvPresenter.new(app.service_bindings).system_env.stringify_keys)
    end
  end
end
