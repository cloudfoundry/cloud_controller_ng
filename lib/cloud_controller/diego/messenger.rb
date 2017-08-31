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

        if do_local_staging
          task_definition = task_recipe_builder.build_staging_task(config, staging_details)
          bbs_stager_client.stage(staging_guid, task_definition)
          @statsd_updater.start_staging_request_received
        else
          staging_message = protocol.stage_package_request(config, staging_details)
          stager_client.stage(staging_guid, staging_message)
        end
      end

      def send_stop_staging_request(staging_guid)
        logger.info('staging.stop', staging_guid: staging_guid)

        if do_local_staging
          bbs_stager_client.stop_staging(staging_guid)
        else
          stager_client.stop_staging(staging_guid)
        end
      end

      def send_desire_request(process, config)
        logger.info('desire.app.begin', app_guid: process.guid)

        process_guid = ProcessGuid.from_process(process)
        if bypass_bridge?
          app_recipe_builder = AppRecipeBuilder.new(config: config, process: process)
          DesireAppHandler.create_or_update_app(process_guid, app_recipe_builder, bbs_apps_client)
        else
          desire_message = protocol.desire_app_request(process, config.get(:default_health_check_timeout))
          nsync_client.desire_app(process_guid, desire_message)
        end
      end

      def send_stop_index_request(process, index)
        logger.info('stop.index', app_guid: process.guid, index: index)

        process_guid = ProcessGuid.from_process(process)
        if bypass_bridge?
          bbs_apps_client.stop_index(process_guid, index)
        else
          nsync_client.stop_index(process_guid, index)
        end
      end

      def send_stop_app_request(process)
        logger.info('stop.app', app_guid: process.guid)

        process_guid = ProcessGuid.from_process(process)
        if bypass_bridge?
          bbs_apps_client.stop_app(process_guid)
        else
          nsync_client.stop_app(process_guid)
        end
      end

      private

      def do_local_staging
        !!Config.config.get(:diego, :temporary_local_staging)
      end

      def logger
        @logger ||= Steno.logger('cc.diego.messenger')
      end

      def protocol
        @protocol ||= Protocol.new
      end

      def task_recipe_builder
        @task_recipe_builder ||= TaskRecipeBuilder.new
      end

      def stager_client
        CloudController::DependencyLocator.instance.stager_client
      end

      def bbs_apps_client
        CloudController::DependencyLocator.instance.bbs_apps_client
      end

      def bbs_stager_client
        CloudController::DependencyLocator.instance.bbs_stager_client
      end

      def nsync_client
        CloudController::DependencyLocator.instance.nsync_client
      end

      def bypass_bridge?
        !!Config.config.get(:diego, :temporary_local_apps)
      end
    end
  end
end
