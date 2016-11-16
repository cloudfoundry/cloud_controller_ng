require 'diego/action_builder'

module VCAP::CloudController
  module Diego
    module Buildpack
      class TaskActionBuilder
        include ::Diego::ActionBuilder

        def initialize(task)
          @task = task
        end

        def action(lifecycle_data)
          serial([
            ::Diego::Bbs::Models::DownloadAction.new(
              from: lifecycle_data[:droplet_download_uri],
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
              env: envs_for_diego(task)
            ),
          ])
        end

        def task_environment_variables
          envs_for_diego task
        end

        private

        attr_reader :task

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
