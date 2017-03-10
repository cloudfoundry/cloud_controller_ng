require 'repositories/task_event_repository'

module VCAP::CloudController
  class TaskCreate
    class InvalidTask < StandardError; end
    class TaskCreateError < StandardError; end
    class NoAssignedDroplet < TaskCreateError; end
    class MaximumDiskExceeded < TaskCreateError; end

    def initialize(config)
      @config = config
    end

    def create(app, message, user_audit_info, droplet: nil)
      droplet ||= app.droplet
      no_assigned_droplet! unless droplet
      validate_maximum_disk!(message)

      task = nil
      TaskModel.db.transaction do
        app.lock!

        task = TaskModel.create(
          name:                  use_requested_name_or_generate_name(message),
          state:                 TaskModel::PENDING_STATE,
          droplet:               droplet,
          command:               message.command,
          app:                   app,
          disk_in_mb:            message.disk_in_mb || config[:default_app_disk_in_mb],
          memory_in_mb:          message.memory_in_mb || config[:default_app_memory],
          sequence_id:           app.max_task_sequence_id
        )

        app.update(max_task_sequence_id: app.max_task_sequence_id + 1)

        app_usage_event_repository.create_from_task(task, 'TASK_STARTED')
        task_event_repository.record_task_create(task, user_audit_info)
      end

      submit_task(task)

      task
    rescue Diego::Buildpack::LifecycleProtocol::InvalidDownloadUri,
           Diego::LifecycleBundleUriGenerator::InvalidStack,
           Diego::LifecycleBundleUriGenerator::InvalidCompiler => e
      raise CloudController::Errors::ApiError.new_from_details('TaskError', e.message)
    rescue Sequel::ValidationFailed => e
      raise InvalidTask.new(e.message)
    end

    private

    attr_reader :config

    def submit_task(task)
      if bypass_bridge?
        begin
          task_definition = Diego::TaskRecipeBuilder.new.build_app_task(config, task)
          dependency_locator.bbs_task_client.desire_task(task.guid, task_definition, Diego::TASKS_DOMAIN)
          mark_task_as_running(task)
        rescue => e
          fail_task(task)
          raise e
        end
      else
        dependency_locator.nsync_client.desire_task(task)
      end
    end

    def bypass_bridge?
      config[:diego] && config[:diego][:temporary_local_tasks]
    end

    def use_requested_name_or_generate_name(message)
      message.requested?(:name) ? message.name : Random.new.bytes(4).unpack('H*').first
    end

    def validate_maximum_disk!(message)
      return unless message.requested?(:disk_in_mb)
      raise MaximumDiskExceeded.new("Cannot request disk_in_mb greater than #{config[:maximum_app_disk_in_mb]}") if message.disk_in_mb.to_i > config[:maximum_app_disk_in_mb]
    end

    def dependency_locator
      CloudController::DependencyLocator.instance
    end

    def no_assigned_droplet!
      raise NoAssignedDroplet.new('Task must have a droplet. Specify droplet or assign current droplet to app.')
    end

    def app_usage_event_repository
      Repositories::AppUsageEventRepository.new
    end

    def task_event_repository
      Repositories::TaskEventRepository.new
    end

    def fail_task(task)
      task.db.transaction do
        task.lock!
        task.state = TaskModel::FAILED_STATE
        task.failure_reason = 'Unable to request task to be run'
        task.save
      end
    end

    def mark_task_as_running(task)
      task.db.transaction do
        task.lock!
        task.state = TaskModel::RUNNING_STATE
        task.save
      end
    end
  end
end
