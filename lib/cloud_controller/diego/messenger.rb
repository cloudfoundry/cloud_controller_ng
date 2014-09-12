module VCAP::CloudController
  module Diego
    class Messenger
      def initialize(message_bus, protocol)
        @message_bus = message_bus
        @protocol = protocol
      end

      def send_stage_request(app)
        app.update(staging_task_id: VCAP.secure_uuid)
        logger.info("staging.begin", :app_guid => app.guid)
        @message_bus.publish(*@protocol.stage_app_request(app))
      end

      def send_desire_request(app)
        logger.info("desire.app.begin", :app_guid => app.guid)
        @message_bus.publish(*@protocol.desire_app_request(app))
      end

      private

      def logger
        @logger ||= Steno.logger("cc.diego.messenger")
      end
    end
  end
end
