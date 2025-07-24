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

          # Stack deprecation warning will be handled by the build_create action
          buildpack_keys = if lifecycle.respond_to?(:buildpack_infos)
                             lifecycle.buildpack_infos.map(&:key)
                           else
                             lifecycle_data[:buildpacks]&.map { |bp| bp[:key] } || [] # rubocop:disable Rails/Pluck
                           end

          skip_detect = if lifecycle.respond_to?(:skip_detect?)
                          lifecycle.skip_detect?
                        else
                          lifecycle_data[:buildpacks]&.any? { |bp| bp[:skip_detect] } || false
                        end

          ::Diego::Bbs::Models::RunAction.new(
            path: '/tmp/lifecycle/builder',
            user: 'vcap',
            args: [
              "-buildpackOrder=#{buildpack_keys.join(',')}",
              "-skipCertVerify=#{config.get(:skip_cert_verify)}",
              "-skipDetect=#{skip_detect}",
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
