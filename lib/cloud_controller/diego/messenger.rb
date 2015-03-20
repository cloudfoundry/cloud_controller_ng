module VCAP::CloudController
  module Diego
    class Messenger
      def initialize(stager_client, message_bus, protocol)
        @stager_client = stager_client
        @message_bus = message_bus
        @protocol = protocol
      end

      def send_stage_request(app, staging_config)
        logger.info('staging.begin', app_guid: app.guid)

        staging_guid = StagingGuid.from_app(app)
        staging_message = @protocol.stage_app_request(app, staging_config)
        @stager_client.stage(staging_guid, staging_message)
      end

      def send_stop_staging_request(app)
        logger.info('staging.stop', app_guid: app.guid)

        staging_guid = StagingGuid.from_app(app)
        @stager_client.stop_staging(staging_guid)
      end

      def send_desire_request(app, default_health_check_timeout)
        logger.info('desire.app.begin', app_guid: app.guid)
        @message_bus.publish(*@protocol.desire_app_request(app, default_health_check_timeout))
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
