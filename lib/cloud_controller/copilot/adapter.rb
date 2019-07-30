require 'cf-copilot'

module VCAP::CloudController
  module Copilot
    class Adapter
      class CopilotUnavailable < StandardError
      end

      class << self
        def create_route(route)
          with_guardrails(route: route) do
            copilot_client.upsert_route(
              guid: route.guid,
              host: route.fqdn,
              path: route.path,
              internal: route.internal?,
              vip: route.vip
            )
          end
          logger.debug("Upsert route with GUID: #{route.guid} and vip: #{route.vip}")
        end

        def map_route(route_mapping)
          with_guardrails(route: route_mapping.route) do
            route_mapping.processes.each do |process|
              copilot_client.map_route(
                capi_process_guid: process.guid,
                route_guid: route_mapping.route_guid,
                route_weight: route_mapping.adapted_weight
              )
            end
          end
        end

        def unmap_route(route_mapping)
          with_guardrails(route: route_mapping.route) do
            route_mapping.processes.each do |process|
              copilot_client.unmap_route(
                capi_process_guid: process.guid,
                route_guid: route_mapping.route_guid,
                route_weight: route_mapping.adapted_weight
              )
            end
          end
        end

        def upsert_capi_diego_process_association(process)
          with_guardrails do
            copilot_client.upsert_capi_diego_process_association(
              capi_process_guid: process.guid,
              diego_process_guids: [Diego::ProcessGuid.from_process(process)]
            )
          end
        end

        def delete_capi_diego_process_association(process)
          with_guardrails do
            copilot_client.delete_capi_diego_process_association(capi_process_guid: process.guid)
          end
        end

        def bulk_sync(routes:, route_mappings:, capi_diego_process_associations:)
          copilot_client.bulk_sync(
            routes: routes,
            route_mappings: route_mappings,
            capi_diego_process_associations: capi_diego_process_associations,
          )
        rescue StandardError => e
          raise CopilotUnavailable.new(e.message)
        end

        private

        def copilot_client
          CloudController::DependencyLocator.instance.copilot_client
        end

        def with_guardrails(route: nil)
          return unless Config.config.get(:copilot, :enabled)

          if route
            return unless Config.config.get(:copilot, :temporary_istio_domains).include?(route.domain.name)
          end

          yield
        rescue StandardError => e
          logger.error("failed communicating with copilot backend: #{e.message}")
        end

        def logger
          Steno.logger('copilot_adapter')
        end
      end
    end
  end
end
