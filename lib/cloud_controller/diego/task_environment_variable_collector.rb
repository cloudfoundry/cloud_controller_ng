module VCAP::CloudController
  module Diego
    class TaskEnvironmentVariableCollector
      class << self
        def for_task(task)
          app = task.app
          running_envs = VCAP::CloudController::EnvironmentVariableGroup.running.environment_json
          envs = VCAP::CloudController::Diego::TaskEnvironment.new(app, task, app.space, running_envs).build
          diego_envs = VCAP::CloudController::Diego::BbsEnvironmentBuilder.build(envs)

          logger.debug2("task environment: #{diego_envs.map(&:name)}")

          diego_envs
        end

        private

        def logger
          @logger ||= Steno.logger('cc.diego.tr')
        end
      end
    end
  end
end
