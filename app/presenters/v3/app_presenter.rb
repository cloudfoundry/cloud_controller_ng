require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class AppPresenter < BasePresenter
        def to_hash
          {
            guid:                    app.guid,
            name:                    app.name,
            desired_state:           app.desired_state,
            total_desired_instances: app.processes.map(&:instances).reduce(:+) || 0,
            created_at:              app.created_at,
            updated_at:              app.updated_at,
            lifecycle:               {
              type: app.lifecycle_type,
              data: app.lifecycle_data.to_hash
            },
            environment_variables:   redact_hash(app.environment_variables || {}),
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
            self:           { href: url_builder.build_url(path: "/v3/apps/#{app.guid}") },
            space:          { href: url_builder.build_url(path: "/v2/spaces/#{app.space_guid}") },
            processes:      { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/processes") },
            route_mappings: { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/route_mappings") },
            packages:       { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/packages") },
            droplet:        { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/droplets/current") },
            droplets:       { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/droplets") },
            tasks:          { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/tasks") },
            start:          { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/start"), method: 'PUT' },
            stop:           { href: url_builder.build_url(path: "/v3/apps/#{app.guid}/stop"), method: 'PUT' },
          }

          links.delete_if { |_, v| v.nil? }
        end
      end
    end
  end
end
