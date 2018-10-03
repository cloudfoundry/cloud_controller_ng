require 'cf-copilot'

module VCAP::CloudController
  module Copilot
    class Adapter
      class CopilotUnavailable < StandardError
      end

      class << self
        def create_route(route)
          with_guardrails do
            copilot_client.upsert_route(
              guid: route.guid,
              host: route.fqdn,
              path: route.path,
            )
          end
        end

        def map_route(route_mapping)
          with_guardrails do
            copilot_client.map_route(
              capi_process_guid: route_mapping.process.guid,
              route_guid: route_mapping.route.guid,
              route_weight: route_mapping.weight
            )
          end
        end

        def unmap_route(route_mapping)
          with_guardrails do
            copilot_client.unmap_route(
              capi_process_guid: route_mapping.process.guid,
              route_guid: route_mapping.route.guid,
              route_weight: route_mapping.weight
            )
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

        def bulk_sync(routes:, route_mappings:, processes:)
          copilot_client.bulk_sync(
            routes: routes.compact.map { |r| { guid: r.guid, host: r.fqdn, path: r.path } },
            route_mappings: route_mappings.compact.map do |rm|
              next if rm.process.nil? || rm.route.nil?
              {
                capi_process_guid: rm.process.guid,
                route_guid: rm.route.guid,
                route_weight: rm.weight
              }
            end.compact,
            capi_diego_process_associations: processes.compact.map do |process|
              {
                  capi_process_guid: process.guid,
                  diego_process_guids: [Diego::ProcessGuid.from_process(process)]
              }
            end
          )
        rescue StandardError => e
          raise CopilotUnavailable.new(e.message)
        end

        private

        def copilot_client
          CloudController::DependencyLocator.instance.copilot_client
        end

        def with_guardrails
          return unless Config.config.get(:copilot, :enabled)

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
