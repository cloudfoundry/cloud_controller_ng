require 'cloud_controller/dependency_locator'

module VCAP::CloudController
  module Diego
    class Messenger
      attr_reader :process

      def initialize(process)
        @process = process
      end

      def send_stage_request(config)
        logger.info('staging.begin', app_guid: process.guid)

        staging_guid = StagingGuid.from_process(process)
        staging_message = protocol.stage_app_request(config)
        stager_client.stage(staging_guid, staging_message)
      end

      def send_stop_staging_request
        logger.info('staging.stop', app_guid: process.guid)

        staging_guid = StagingGuid.from_process(process)
        stager_client.stop_staging(staging_guid)
      end

      def send_desire_request(default_health_check_timeout)
        logger.info('desire.app.begin', app_guid: process.guid)

        process_guid = ProcessGuid.from_process(process)
        desire_message = protocol.desire_app_request(default_health_check_timeout)
        nsync_client.desire_app(process_guid, desire_message)
      end

      def send_stop_index_request(index)
        logger.info('stop.index', app_guid: process.guid, index: index)

        process_guid = ProcessGuid.from_process(process)
        nsync_client.stop_index(process_guid, index)
      end

      def send_stop_app_request
        logger.info('stop.app', app_guid: process.guid)

        process_guid = ProcessGuid.from_process(process)
        nsync_client.stop_app(process_guid)
      end

      private

      def logger
        @logger ||= Steno.logger('cc.diego.messenger')
      end

      def protocol
        @protocol ||= Protocol.new(process)
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
