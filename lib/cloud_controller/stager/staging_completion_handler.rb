module VCAP::CloudController
  class StagingCompletionHandler
    attr_reader :message_bus

    def initialize(message_bus)
      @message_bus = message_bus
    end

    class Message
      def initialize(response)
        @response = response
      end

      def app_id
        @response["app_id"]
      end

      def detected_buildpack
        @response["detected_buildpack"]
      end

      def task_id
        @response["task_id"]
      end

      def error
        @response["error"]
      end

      def log
        @response["task_log"]
      end
    end

    def subscribe!
      @message_bus.subscribe("diego.staging.finished", queue: "cc") do |payload|
        message = Message.new(payload)
        app = App.find(guid: message.app_id)

        if message.task_id != app.staging_task_id
          logger.info(
            "diego.staging.not-current",
            :response => payload,
            :current => app.staging_task_id,
          )

          next
        end

        DeaClient.start(app, instances_to_start: app.instances)

        logger.info("diego.staging.finished", :response => payload)

        if message.error
          app.mark_as_failed_to_stage
          Loggregator.emit_error(app.guid, "Failed to stage application: #{message.error}")
        else
          app.detected_buildpack = message.detected_buildpack
          app.save
        end
      end
    end

    def logger
      @logger ||= Steno.logger("cc.stager")
    end
  end
end

