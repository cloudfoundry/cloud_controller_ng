require 'credhub/config_helpers'
require 'diego/action_builder'
require 'cloud_controller/diego/staging_action_builder'
require 'digest/xxhash'

module VCAP::CloudController
  module Diego
    module CNB
      class StagingActionBuilder < VCAP::CloudController::Diego::StagingActionBuilder
        def initialize(config, staging_details, lifecycle_data)
          super(config, staging_details, lifecycle_data, 'cnb', '/home/vcap/workspace', '/tmp/cache-output.tgz', ::Diego::Bbs::Models::ImageLayer::MediaType::TGZ)
        end

        def cached_dependencies
          return nil if @config.get(:diego, :enable_declarative_asset_downloads)

          [
            ::Diego::Bbs::Models::CachedDependency.new(
              from: LifecycleBundleUriGenerator.uri(config.get(:diego, :lifecycle_bundles)[lifecycle_bundle_key]),
              to: '/tmp/lifecycle',
              cache_key: "#{@prefix}-#{lifecycle_stack}-lifecycle"
            )
          ]
        end

        def task_environment_variables
          env = [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_USER_ID', value: '2000'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_GROUP_ID', value: '2000'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_STACK_ID', value: lifecycle_stack),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: STAGING_DEFAULT_LANG)
          ]
          env.push(::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_REGISTRY_CREDS', value: lifecycle_data[:credentials])) if lifecycle_data[:credentials]
          env
        end

        private

        def stage_action
          args = [
            '--cache-dir', '/tmp/cache',
            '--cache-output', '/tmp/cache-output.tgz'
          ]

          lifecycle_data[:buildpacks].each do |buildpack|
            args.push('--buildpack', buildpack[:url])
          end

          env_vars = BbsEnvironmentBuilder.build(staging_details.environment_variables)
          env_vars.each do |e|
            args.push('--pass-env-var', e.name)
          end

          ::Diego::Bbs::Models::RunAction.new(
            path: '/tmp/lifecycle/builder',
            user: 'vcap',
            args: args,
            env: env_vars
          )
        end
      end
    end
  end
end
