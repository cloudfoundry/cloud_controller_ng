require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class RouteMappingPresenter < BasePresenter
        def to_hash
          {
            guid: route_mapping.guid,
            app_port: route_mapping.app_port,
            created_at: route_mapping.created_at,
            updated_at: route_mapping.updated_at,
            links: build_links
          }
        end

        private

        def route_mapping
          @resource
        end

        def build_links
          process_link = nil
          unless route_mapping.process_type.blank?
            process_link = { href: "/v3/apps/#{route_mapping.app.guid}/processes/#{route_mapping.process_type}" }
          end

          {
            self:  { href: "/v3/route_mappings/#{route_mapping.guid}" },
            app:   { href: "/v3/apps/#{route_mapping.app.guid}" },
            route: { href: "/v2/routes/#{route_mapping.route.guid}" },
            process: process_link
          }
        end
      end
    end
  end
end
