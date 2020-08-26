require_relative 'base_presenter'

module VCAP
  module CloudController
    module Presenters
      module V3
        class ServiceRouteBindingPresenter < BasePresenter
          def to_hash
            {
              guid: binding.guid,
              created_at: binding.created_at,
              updated_at: binding.updated_at,
              last_operation: last_operation,
              relationships: relationships,
              links: links
            }
          end

          private

          def binding
            @resource
          end

          def last_operation
            return nil if binding.last_operation.blank?

            last_operation = binding.last_operation

            {
              type: last_operation.type,
              state: last_operation.state,
              description: last_operation.description,
              created_at: last_operation.created_at,
              updated_at: last_operation.updated_at
            }
          end

          def links
            {
              self: {
                href: url_builder.build_url(path: "/v3/service_route_bindings/#{binding.guid}")
              },
              service_instance: {
                href: url_builder.build_url(path: "/v3/service_instances/#{binding.service_instance.guid}")
              },
              route: {
                href: url_builder.build_url(path: "/v3/routes/#{binding.route.guid}")
              }
            }
          end

          def relationships
            {
              service_instance: { data: { guid: binding.service_instance.guid } },
              route: { data: { guid: binding.route.guid } }
            }
          end
        end
      end
    end
  end
end
