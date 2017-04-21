require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class RouteMappingPresenter < BasePresenter
        def to_hash
          {
            guid: route_mapping.guid,
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
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          unless route_mapping.process_type.blank?
            process_link = { href: url_builder.build_url(path: "/v3/apps/#{route_mapping.app.guid}/processes/#{route_mapping.process_type}") }
          end

          {
            self:  { href: url_builder.build_url(path: "/v3/route_mappings/#{route_mapping.guid}") },
            app:   { href: url_builder.build_url(path: "/v3/apps/#{route_mapping.app.guid}") },
            route: { href: url_builder.build_url(path: "/v2/routes/#{route_mapping.route.guid}") },
            process: process_link
          }
        end
      end
    end
  end
end
