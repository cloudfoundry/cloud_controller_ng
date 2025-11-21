require 'credhub/config_helpers'
require 'diego/action_builder'
require 'digest/xxhash'
require 'cloud_controller/diego/staging_action_builder'

module VCAP::CloudController
  module Diego
    module Buildpack
      class StagingActionBuilder < VCAP::CloudController::Diego::StagingActionBuilder
        def initialize(config, staging_details, lifecycle_data)
          super(config, staging_details, lifecycle_data, 'buildpack', '/tmp/app', '/tmp/output-cache', ::Diego::Bbs::Models::ImageLayer::MediaType::ZIP)
        end

        def task_environment_variables
          [::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: STAGING_DEFAULT_LANG)]
        end

        private

        def lifecycle
          staging_details.lifecycle
        end

        def stage_action
          staging_details_env = BbsEnvironmentBuilder.build(staging_details.environment_variables)

          main_staging_action = ::Diego::Bbs::Models::RunAction.new(
            path: '/tmp/lifecycle/builder',
            user: 'vcap',
            args: [
              "-buildpackOrder=#{lifecycle.buildpack_infos.map(&:key).join(',')}",
              "-skipCertVerify=#{config.get(:skip_cert_verify)}",
              "-skipDetect=#{lifecycle.skip_detect?}",
              '-buildDir=/tmp/app',
              '-outputDroplet=/tmp/droplet',
              '-outputMetadata=/tmp/result.json',
              '-outputBuildArtifactsCache=/tmp/output-cache',
              '-buildpacksDir=/tmp/buildpacks',
              '-buildArtifactsCacheDir=/tmp/cache'
            ],
            resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: config.get(:staging, :minimum_staging_file_descriptor_limit)),
            env: staging_details_env + platform_options_env
          )

          # Check if stack has warnings and add them if needed
          stack = Stack.find(name: lifecycle.staging_stack)
          warning_actions = []

          if stack&.state == 'DEPRECATED'
            warning_message = "\033[1;33mWARNING: Stack '#{stack.name}' is deprecated. #{stack.description}\033[0m"
            warning_actions << ::Diego::Bbs::Models::RunAction.new(
              path: '/bin/echo',
              user: 'vcap',
              args: ['-e', warning_message],
              env: staging_details_env + platform_options_env
            )
          elsif stack&.state == 'LOCKED'
            warning_message = "\033[1;33mNOTICE: Stack '#{stack.name}' is locked and can only be used to update existing applications. #{stack.description}\033[0m"
            warning_actions << ::Diego::Bbs::Models::RunAction.new(
              path: '/bin/echo',
              user: 'vcap',
              args: ['-e', warning_message],
              env: staging_details_env + platform_options_env
            )
          end

          if warning_actions.any?
            serial(warning_actions + [main_staging_action])
          else
            main_staging_action
          end
        end

        def platform_options_env
          arr = []
          arr << ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_PLATFORM_OPTIONS', value: credhub_url) if credhub_url.present? && cred_interpolation_enabled?

          arr
        end
      end
    end
  end
end
