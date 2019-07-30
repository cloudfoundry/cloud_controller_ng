module VCAP::CloudController
  module Copilot
    class Sync
      BATCH_SIZE = 500

      def self.sync
        logger = Steno.logger('cc.copilot.sync')
        logger.info('run-copilot-sync')

        routes = batch(route_batch_query)
        route_mappings = batch(route_mappings_batch_query)
        web_processes = batch(processes_batch_query)

        Adapter.bulk_sync(
          routes: routes.map { |r| { guid: r.guid, host: r.fqdn, path: r.path, internal: r.internal?, vip: r.vip } },
          route_mappings: route_mappings.reject { |rm| rm.process.nil? }.map do |rm|
            {
              capi_process_guid: rm.process.guid,
              route_guid: rm.route_guid,
              route_weight: rm.adapted_weight
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

      def self.batch(query)
        last_id = 0

        resources = []
        loop do
          batch = query.call(last_id).all

          resources.concat(batch)

          return resources if batch.count < BATCH_SIZE

          last_id = resources.last.id
        end
      end

      def self.route_batch_query
        proc { |last_id|
          routes = Route.
                   where(Sequel.lit("#{Route.table_name}.id > ?", last_id)).
                   order("#{Route.table_name}__id".to_sym).
                   join(:domains, [[:id, :domain_id], [:name, allowed_domains]]).
                   eager(:domain).
                   limit(BATCH_SIZE)

          routes.select_all(Route.table_name)
        }
      end

      def self.route_mappings_batch_query
        proc { |last_id|
          route_mappings = RouteMappingModel.
                           where(Sequel.lit("#{RouteMappingModel.table_name}.id > ?", last_id)).
                           order("#{RouteMappingModel.table_name}__id".to_sym).
                           join(:routes, guid: :route_guid).
                           join(:domains, [[:id, :domain_id], [:name, allowed_domains]]).
                           eager(:process).
                           limit(BATCH_SIZE)

          route_mappings.select_all(RouteMappingModel.table_name)
        }
      end

      def self.processes_batch_query
        proc { |last_id|
          processes = ProcessModel.
                      where(Sequel.lit("#{ProcessModel.table_name}.id > ?", last_id)).
                      where(type: ProcessTypes::WEB).
                      order("#{ProcessModel.table_name}__id".to_sym).
                      limit(BATCH_SIZE)

          processes.select_all(ProcessModel.table_name)
        }
      end

      def self.allowed_domains
        Config.config.get(:copilot, :temporary_istio_domains)
      end
    end
  end
end
