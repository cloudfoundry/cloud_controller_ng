require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class AppEnvPresenter < BasePresenter
        attr_reader :app

        def initialize(app, show_secrets)
          super(app, show_secrets:)
          @app = app
        end

        def to_hash
          vars_builder = VCAP::VarsBuilder.new(
            app,
            file_descriptors: Config.config.get(:instance_file_descriptor_limit)
          )

          vcap_application = {
            VCAP_APPLICATION: vars_builder.to_hash
          }

          {
            environment_variables: app.environment_variables,
            staging_env_json: EnvironmentVariableGroup.staging.environment_json,
            running_env_json: EnvironmentVariableGroup.running.environment_json,
            system_env_json: redact_hash(SystemEnvPresenter.new(app).system_env),
            application_env_json: vcap_application
          }
        end
      end
    end
  end
end
