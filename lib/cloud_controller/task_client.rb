module CloudController
  class TaskClient
    attr_reader :message_bus

    def initialize(message_bus)
      @message_bus = message_bus
    end

    def start_task(task)
      @message_bus.publish(
        "task.start",
        task: task.guid,
        secure_token: task.secure_token,
        package: VCAP::CloudController::StagingsController.droplet_download_uri(task.app),
      )
    end

    def stop_task(task)
      @message_bus.publish(
        "task.stop",
        task: task.guid,
      )
    end
  end
end
