require 'cloud_controller/dependency_locator'
require 'cloud_controller/diego/desire_app_handler'

module VCAP::CloudController
  module Diego
    class Messenger
      def initialize(statsd_updater=VCAP::CloudController::Metrics::StatsdUpdater.new)
        @statsd_updater = statsd_updater
      end

      def send_stage_request(config, staging_details)
        logger.info('staging.begin', package_guid: staging_details.package.guid)

        staging_guid = staging_details.staging_guid

        bbs_stager_client.stage(staging_guid, staging_details)
        @statsd_updater.start_staging_request_received
      end

      def send_stop_staging_request(staging_guid)
        logger.info('staging.stop', staging_guid: staging_guid)

        bbs_stager_client.stop_staging(staging_guid)
      end

      def send_desire_request(process)
        logger.info('desire.app.begin', app_guid: process.guid)
        DesireAppHandler.create_or_update_app(process, bbs_apps_client)
      end

      def send_stop_index_request(process, index)
        logger.info('stop.index', app_guid: process.guid, index: index)

        process_guid = ProcessGuid.from_process(process)
        bbs_apps_client.stop_index(process_guid, index)
      end

      def send_stop_app_request(process)
        logger.info('stop.app', app_guid: process.guid)

        process_guid = ProcessGuid.from_process(process)
        bbs_apps_client.stop_app(process_guid)
      end

      private

      def logger
        @logger ||= Steno.logger('cc.diego.messenger')
      end

      def protocol
        @protocol ||= Protocol.new
      end

      def bbs_apps_client
        CloudController::DependencyLocator.instance.bbs_apps_client
      end

      def bbs_stager_client
        CloudController::DependencyLocator.instance.bbs_stager_client
      end
    end
  end
end
