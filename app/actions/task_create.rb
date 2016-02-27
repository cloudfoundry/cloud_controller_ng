require 'cloud_controller/diego/v3/environment'
require 'repositories/runtime/task_event_repository'

module VCAP::CloudController
  class TaskCreate
    class InvalidTask < StandardError; end
    class TaskCreateError < StandardError; end
    class NoAssignedDroplet < TaskCreateError; end

    def initialize(config)
      @config = config
    end

    def create(app, message, user_guid, user_email, droplet: nil)
      droplet ||= app.droplet
      no_assigned_droplet! unless droplet

      task = nil
      TaskModel.db.transaction do
        task = TaskModel.create(
          name:                  message.name,
          state:                 TaskModel::PENDING_STATE,
          droplet:               droplet,
          command:               message.command,
          app:                   app,
          memory_in_mb:          message.memory_in_mb || config[:default_app_memory],
          environment_variables: message.environment_variables
        )

        app_usage_event_repository.create_from_task(task, 'TASK_STARTED')
        task_event_repository.record_task_create(task, user_guid, user_email)
      end

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

    def app_usage_event_repository
      Repositories::Runtime::AppUsageEventRepository.new
    end

    def task_event_repository
      Repositories::Runtime::TaskEventRepository.new
    end
  end
end
