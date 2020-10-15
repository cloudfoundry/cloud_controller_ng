require_relative 'base_presenter'
require 'presenters/mixins/last_operation_helper'

module VCAP
  module CloudController
    module Presenters
      module V3
        class ServiceRouteBindingPresenter < BasePresenter
          include VCAP::CloudController::Presenters::Mixins::LastOperationHelper

          def to_hash
            base.merge(decorations)
          end

          private

          def base
            {
              guid: binding.guid,
              route_service_url: binding.route_service_url,
              created_at: binding.created_at,
              updated_at: binding.updated_at,
              last_operation: last_operation(binding),
              relationships: relationships,
              links: links
            }
          end

          def decorations
            @decorators.reduce({}) { |memo, d| d.decorate(memo, [@resource]) }
          end

          def binding
            @resource
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
            }.tap do |l|
              if binding.service_instance.managed_instance?
                l[:parameters] = { href: url_builder.build_url(path: "/v3/service_route_bindings/#{binding.guid}/parameters") }
              end
            end
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
