require 'cloud_controller/diego/v3/environment'

module VCAP::CloudController
  class TaskCreate
    class InvalidTask < StandardError; end
    class TaskCreateError < StandardError; end
    class NoAssignedDroplet < TaskCreateError; end

    def initialize(config)
      @config = config
    end

    def create(app, message)
      no_assigned_droplet! unless app.droplet
      task = TaskModel.create(
        name: message.name,
        state: TaskModel::RUNNING_STATE,
        droplet: app.droplet,
        command: message.command,
        app: app,
        memory_in_mb: message.memory_in_mb || config[:default_app_memory],
        environment_variables: message.environment_variables
      )
      dependency_locator.nsync_client.desire_task(task)
      task
    rescue Sequel::ValidationFailed => e
      raise InvalidTask.new(e.message)
    end

    private

    attr_reader :config

    def dependency_locator
      CloudController::DependencyLocator.instance
    end

    def no_assigned_droplet!
      raise NoAssignedDroplet.new('Task must have a droplet. Specify droplet or assign current droplet to app.')
    end
  end
end
