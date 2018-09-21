module VCAP::CloudController
  module Copilot
    class Sync
      def self.sync
        logger = Steno.logger('cc.copilot.sync')

        logger.info('run-copilot-sync')
        Adapter.bulk_sync(
          # please do not do Route.all, we need to only fetch Guid and fqdn,
          # fqdn will require eager loading domains in the sql query
          routes: Route.all,
          route_mappings: RouteMappingModel.all,
          processes: ProcessModel.where(type: ProcessTypes::WEB).all
        )
        logger.info('finished-copilot-sync')
      end
    end
  end
end
