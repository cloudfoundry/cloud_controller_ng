require_relative 'base_presenter'

module VCAP
  module CloudController
    module Presenters
      module V3
        class ServiceRouteBindingPresenter < BasePresenter
          def to_hash
            {
              guid: @resource.guid,
              created_at: @resource.created_at,
              updated_at: @resource.updated_at,
              relationships: relationships,
              links: links
            }
          end

          private

          def links
            {
              self: {
                href: url_builder.build_url(path: "/v3/service_route_bindings/#{@resource.guid}")
              },
              service_instance: {
                href: url_builder.build_url(path: "/v3/service_instances/#{@resource.service_instance.guid}")
              },
              route: {
                href: url_builder.build_url(path: "/v3/routes/#{@resource.route.guid}")
              }
            }
          end

          def relationships
            {
              service_instance: { data: { guid: @resource.service_instance.guid } },
              route: { data: { guid: @resource.route.guid } }
            }
          end
        end
      end
    end
  end
end
