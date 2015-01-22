module VCAP::CloudController
  module Diego
    class Messenger
      def initialize(message_bus, protocol)
        @message_bus = message_bus
        @protocol = protocol
      end

      def send_stage_request(app, staging_config)
        logger.info('staging.begin', app_guid: app.guid)
        @message_bus.publish(*@protocol.stage_app_request(app, staging_config))
      end

      def send_desire_request(app)
        logger.info('desire.app.begin', app_guid: app.guid)
        @message_bus.publish(*@protocol.desire_app_request(app))
      end

      def send_stop_staging_request(app, task_id)
        logger.info('staging.stop', app_guid: app.guid, task_id: task_id)
        @message_bus.publish(*@protocol.stop_staging_app_request(app, task_id))
      end

      def send_stop_index_request(app, index)
        logger.info('stop.index', app_guid: app.guid, index: index)
        @message_bus.publish(*@protocol.stop_index_request(app, index))
      end

      private

      def logger
        @logger ||= Steno.logger('cc.diego.messenger')
      end
    end
  end
end
