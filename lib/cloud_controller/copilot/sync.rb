module VCAP::CloudController
  module Copilot
    class Sync
      def self.sync
        logger = Steno.logger('cc.copilot.sync')
        logger.info('run-copilot-sync')

        routes = Route.eager(:domain).all
        route_mappings = RouteMappingModel.eager(:process).all
        web_processes = ProcessModel.where(type: ProcessTypes::WEB).all

        Adapter.bulk_sync(
          routes: routes.map { |r| { guid: r.guid, host: r.fqdn, path: r.path } },
          route_mappings: route_mappings.reject { |rm| rm.process.nil? }.map do |rm|
            {
              capi_process_guid: rm.process.guid,
              route_guid: rm.route_guid,
              route_weight: rm.weight
            }
          end,
          capi_diego_process_associations: web_processes.map do |process|
            {
              capi_process_guid: process.guid,
              diego_process_guids: [Diego::ProcessGuid.from_process(process)]
            }
          end
        )

        logger.info('finished-copilot-sync')
      end
    end
  end
end
