module CloudController
  class TaskClient
    attr_reader :message_bus

    def initialize(message_bus, blobstore_url_generator)
      @message_bus = message_bus
      @blobstore_url_generator = blobstore_url_generator
    end

    def start_task(task)
      @message_bus.publish(
        "task.start",
        task: task.guid,
        secure_token: task.secure_token,
        package: @blobstore_url_generator.droplet_download_url(task.app),
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
