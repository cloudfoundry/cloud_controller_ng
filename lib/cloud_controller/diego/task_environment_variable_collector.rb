require 'cloud_controller/diego/task_environment'

module VCAP::CloudController
  module Diego
    class TaskEnvironmentVariableCollector
      class << self
        def for_task(task)
          app = task.app
          running_envs = VCAP::CloudController::EnvironmentVariableGroup.running.environment_json
          envs = VCAP::CloudController::Diego::TaskEnvironment.new(app, task, app.space, running_envs).build
          diego_envs = VCAP::CloudController::Diego::BbsEnvironmentBuilder.build(envs)
          diego_envs += optional_windows_envs(app)

          logger.debug2("task environment: #{diego_envs.map(&:name)}")

          diego_envs
        end

        private

        def optional_windows_envs(app)
          VCAP::CloudController::Diego::WindowsEnvironmentSage.ponder(app)
        end

        def logger
          @logger ||= Steno.logger('cc.diego.tr')
        end
      end
    end
  end
end
