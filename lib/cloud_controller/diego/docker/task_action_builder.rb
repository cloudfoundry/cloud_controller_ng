require 'diego/action_builder'
require 'cloud_controller/diego/docker/docker_uri_converter'

module VCAP::CloudController
  module Diego
    module Docker
      class TaskActionBuilder
        def initialize(config, task, lifecycle_data)
          @task = task
          @lifecycle_data = lifecycle_data
          @config = config
        end

        def action
          ::Diego::ActionBuilder.action(
            ::Diego::Bbs::Models::RunAction.new(
              user: 'root',
              path: '/tmp/lifecycle/launcher',
              args: ['app', task.command, '{}'],
              log_source: "APP/TASK/#{task.name}",
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new,
              env: task_environment_variables,
            )
          )
        end

        def task_environment_variables
          envs_for_diego(task)
        end

        def stack
          DockerURIConverter.new.convert(lifecycle_data[:droplet_path])
        end

        def lifecycle_bundle_key
          'docker'.to_sym
        end

        def cached_dependencies
          [::Diego::Bbs::Models::CachedDependency.new(
            from: LifecycleBundleUriGenerator.uri(config[:diego][:lifecycle_bundles][lifecycle_bundle_key]),
            to: '/tmp/lifecycle',
            cache_key: 'docker-lifecycle',
          )]
        end

        private

        attr_reader :config, :task, :lifecycle_data

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
