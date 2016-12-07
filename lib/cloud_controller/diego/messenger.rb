require 'cloud_controller/dependency_locator'
require 'cloud_controller/diego/desire_app_handler'

module VCAP::CloudController
  module Diego
    class Messenger
      def send_stage_request(config, staging_details)
        logger.info('staging.begin', package_guid: staging_details.package.guid)

        staging_guid = staging_details.droplet.guid

        if do_local_staging
          task_definition = recipe_builder.build_staging_task(config, staging_details)
          bbs_stager_client.stage(staging_guid, task_definition)
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
          desire_message = protocol.desire_app_message(process, config[:default_health_check_timeout])
          app_recipe_builder = AppRecipeBuilder.new(config: config, process: process, app_request: desire_message)
          DesireAppHandler.create_or_update_app(process_guid, app_recipe_builder, bbs_apps_client)
        else
          desire_message = protocol.desire_app_request(process, config[:default_health_check_timeout])
          nsync_client.desire_app(process_guid, desire_message)
        end
      end

      def send_stop_index_request(process, index)
        logger.info('stop.index', app_guid: process.guid, index: index)

        process_guid = ProcessGuid.from_process(process)
        nsync_client.stop_index(process_guid, index)
      end

      def send_stop_app_request(process)
        logger.info('stop.app', app_guid: process.guid)

        process_guid = ProcessGuid.from_process(process)
        nsync_client.stop_app(process_guid)
      end

      private

      def do_local_staging
        !!HashUtils.dig(Config.config, :diego, :temporary_local_staging)
      end

      def logger
        @logger ||= Steno.logger('cc.diego.messenger')
      end

      def protocol
        @protocol ||= Protocol.new
      end

      def recipe_builder
        @recipe_builder ||= RecipeBuilder.new
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
        !!HashUtils.dig(Config.config, :diego, :temporary_local_apps)
      end
    end
  end
end
