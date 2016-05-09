require 'cloud_controller/dependency_locator'

module VCAP::CloudController
  module Diego
    class Messenger
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def send_stage_request(config)
        logger.info('staging.begin', app_guid: app.guid)

        staging_guid = StagingGuid.from_app(app)
        staging_message = protocol.stage_app_request(config)
        stager_client.stage(staging_guid, staging_message)
      end

      def send_stop_staging_request
        logger.info('staging.stop', app_guid: app.guid)

        staging_guid = StagingGuid.from_app(app)
        stager_client.stop_staging(staging_guid)
      end

      def send_desire_request(default_health_check_timeout)
        logger.info('desire.app.begin', app_guid: app.guid)

        process_guid = ProcessGuid.from_app(app)
        desire_message = protocol.desire_app_request(default_health_check_timeout)
        nsync_client.desire_app(process_guid, desire_message)
      end

      def send_stop_index_request(index)
        logger.info('stop.index', app_guid: app.guid, index: index)

        process_guid = ProcessGuid.from_app(app)
        nsync_client.stop_index(process_guid, index)
      end

      def send_stop_app_request
        logger.info('stop.app', app_guid: app.guid)

        process_guid = ProcessGuid.from_app(app)
        nsync_client.stop_app(process_guid)
      end

      private

      def logger
        @logger ||= Steno.logger('cc.diego.messenger')
      end

      def protocol
        @protocol ||= Protocol.new(app)
      end

      def stager_client
        CloudController::DependencyLocator.instance.stager_client
      end

      def nsync_client
        CloudController::DependencyLocator.instance.nsync_client
      end
    end
  end
end
