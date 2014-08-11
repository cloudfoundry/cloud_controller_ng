module VCAP::CloudController
  module Diego
    class Messenger
      def initialize(enabled, message_bus, protocol)
        @enabled = enabled
        @message_bus = message_bus
        @protocol = protocol
      end

      def send_stage_request(app)
        @enabled or raise VCAP::Errors::ApiError.new_from_details("DiegoDisabled")

        app.update(staging_task_id: VCAP.secure_uuid)
        logger.info("staging.begin", :app_guid => app.guid)
        @message_bus.publish(*@protocol.stage_app_request(app))
      end

      def send_desire_request(app)
        @enabled or raise VCAP::Errors::ApiError.new_from_details("DiegoDisabled")

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
