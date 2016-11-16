require 'diego/action_builder'

module VCAP::CloudController
  module Diego
    module Buildpack
      class TaskActionBuilder
        include ::Diego::ActionBuilder

        def initialize(config, task, lifecycle_data)
          @config = config
          @task = task
          @lifecycle_data = lifecycle_data
        end

        def action
          serial([
            ::Diego::Bbs::Models::DownloadAction.new(
              from: lifecycle_data[:droplet_uri],
              to: '.',
              cache_key: '',
              user: 'vcap',
              checksum_algorithm: 'sha1',
              checksum_value: task.droplet.droplet_hash
            ),
            ::Diego::Bbs::Models::RunAction.new(
              user: 'vcap',
              path: '/tmp/lifecycle/launcher',
              args: ['app', task.command, ''],
              log_source: "APP/TASK/#{task.name}",
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
              env: task_environment_variables
            ),
          ])
        end

        def task_environment_variables
          envs_for_diego task
        end

        def stack
          lifecycle_data[:stack]
        end

        def cached_dependencies
          lifecycle_bundle_key = "buildpack/#{stack}".to_sym
          [::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(config[:diego][:lifecycle_bundles][lifecycle_bundle_key]),
            to: '/tmp/lifecycle',
            cache_key: "buildpack-#{stack}-lifecycle",
          )]
        end

        private

        attr_reader :task, :lifecycle_data, :config

        def envs_for_diego(task)
          app = task.app
          running_envs = VCAP::CloudController::EnvironmentVariableGroup.running.environment_json
          envs = VCAP::CloudController::Diego::TaskEnvironment.new(app, task, app.space, running_envs).build
          diego_envs = VCAP::CloudController::Diego::BbsEnvironmentBuilder.build(envs)

          logger.debug2("task environment: #{diego_envs.map(&:name)}")

          diego_envs
        end

        def logger
          @logger ||= Steno.logger('cc.diego.tr')
        end
      end
    end
  end
end
