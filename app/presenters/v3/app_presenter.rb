require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class AppPresenter < BasePresenter
        def to_hash
          {
            guid:                    app.guid,
            name:                    app.name,
            state:                   app.desired_state,
            created_at:              app.created_at,
            updated_at:              app.updated_at,
            lifecycle:               {
              type: app.lifecycle_type,
              data: app.lifecycle_data.to_hash
            },
            links:                   build_links
          }
        end

        private

        def app
          @resource
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          links = {
            self:                  { href: url_builder.build_url(path: "/v3/apps/#{app.guid}") },
            environment_variables: { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/environment_variables") },
            space:                 { href: url_builder.build_url(path: "/v3/spaces/#{app.space_guid}") },
            processes:             { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/processes") },
            route_mappings:        { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/route_mappings") },
            packages:              { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/packages") },
            current_droplet:       { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/droplets/current") },
            droplets:              { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/droplets") },
            tasks:                 { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/tasks") },
            start:                 { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/actions/start"), method: 'POST' },
            stop:                  { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/actions/stop"), method: 'POST' },
          }

          links.delete_if { |_, v| v.nil? }
        end
      end
    end
  end
end
