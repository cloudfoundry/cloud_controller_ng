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

        def task_environment_variables
          env = [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_USER_ID', value: '2000'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_GROUP_ID', value: '2000'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'LANG', value: STAGING_DEFAULT_LANG)
          ]
          # For custom stacks, CNB_STACK_ID is optional: if a stack_id was provided
          # in lifecycle data, use it; otherwise omit it and let the CNB builder auto-detect.
          # For system stacks, always pass the stack name as CNB_STACK_ID.
          cnb_stack_id = resolve_cnb_stack_id
          env.push(::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_STACK_ID', value: cnb_stack_id)) if cnb_stack_id
          env.push(::Diego::Bbs::Models::EnvironmentVariable.new(name: 'CNB_REGISTRY_CREDS', value: lifecycle_data[:credentials])) if lifecycle_data[:credentials]
          env
        end

        private

        def resolve_cnb_stack_id
          if UriUtils.is_custom_stack_uri?(lifecycle_stack)
            # Use explicitly provided stack_id from lifecycle_data if present, otherwise omit (auto-detect)
            lifecycle_data[:stack_id]
          else
            lifecycle_stack
          end
        end

        def stage_action
          args = [
            '--cache-dir', '/tmp/cache',
            '--cache-output', '/tmp/cache-output.tgz'
          ]

          args.push('--auto-detect') if lifecycle_data[:auto_detect]
          lifecycle_data[:buildpacks].each do |buildpack|
            args.push('--buildpack', buildpack[:url]) if buildpack[:name] == 'custom'
            args.push('--buildpack', buildpack[:key]) unless buildpack[:name] == 'custom'
          end

          env_vars = BbsEnvironmentBuilder.build(staging_details.environment_variables)
          env_vars.each do |e|
            args.push('--pass-env-var', e.name)
          end

          ::Diego::Bbs::Models::RunAction.new(
            path: '/tmp/lifecycle/builder',
            user: 'vcap',
            args: args,
            env: env_vars + platform_options_env
          )
        end
      end
    end
  end
end
