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

        template_process = process_from_template(message)
        task = TaskModel.create(
          name:                  use_requested_name_or_generate_name(message),
          app:                   app,
          state:                 TaskModel::PENDING_STATE,
          droplet:               droplet,
          command:               command(message, template_process),
          disk_in_mb:            disk_in_mb(message, template_process),
          memory_in_mb:          memory_in_mb(message, template_process),
          log_rate_limit:        log_rate_limit(message, template_process),
          sequence_id:           app.max_task_sequence_id
        )

        MetadataUpdate.update(task, message)

        app.update(max_task_sequence_id: app.max_task_sequence_id + 1)
        task_event_repository.record_task_create(task, user_audit_info)
        task
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

    def process_from_template(message)
      return unless message.template_requested?

      process = ProcessModel.find(guid: message.template_process_guid)
      raise CloudController::Errors::ApiError.new_from_details('ProcessNotFound', message.template_process_guid) unless process

      process
    end

    def command(message, template_process)
      return message.command if message.requested?(:command)

      template_process.specified_or_detected_command
    end

    def memory_in_mb(message, template_process)
      message.memory_in_mb || template_process.try(:memory) || config.get(:default_app_memory)
    end

    def log_rate_limit(message, template_process)
      message.log_rate_limit_in_bytes_per_second || template_process.try(:log_rate_limit) || config.get(:default_app_log_rate_limit_in_bytes_per_second)
    end

    def disk_in_mb(message, template_process)
      message.disk_in_mb || template_process.try(:disk_quota) || config.get(:default_app_disk_in_mb)
    end

    def submit_task(task)
      dependency_locator.bbs_task_client.desire_task(task, Diego::TASKS_DOMAIN)
      mark_task_as_running(task)
    rescue => e
      fail_task(task)
      raise e
    end

    def use_requested_name_or_generate_name(message)
      message.requested?(:name) ? message.name : Random.new.bytes(4).unpack1('H*')
    end

    def validate_maximum_disk!(message)
      return unless message.requested?(:disk_in_mb)

      if message.disk_in_mb.to_i > config.get(:maximum_app_disk_in_mb)
        raise MaximumDiskExceeded.new(
          "Cannot request disk_in_mb greater than #{config.get(:maximum_app_disk_in_mb)}"
        )
      end
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
