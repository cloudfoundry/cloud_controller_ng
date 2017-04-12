require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class BuildPresenter < BasePresenter
        def to_hash
          {
            guid: build.guid,
            created_at: build.created_at,
            updated_at: build.updated_at,
            state: build.state,
            error: build.error_description,
            lifecycle: {
              type: build.lifecycle_type,
              data: build.lifecycle_data.to_hash
            },
            package: { guid: build.package_guid },
            droplet: droplet_guid,
            links: build_links,
          }
        end

        private

        def build
          @resource
        end

        def droplet
          @droplet ||= build.droplet
        end

        def droplet_guid
          if build.droplet && VCAP::CloudController::DropletModel::FINAL_STATES.include?(build.droplet.state)
            return { guid: droplet.guid }
          end
          nil
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
          {
            self: { href: url_builder.build_url(path: "/v3/builds/#{build.guid}") },
            app: { href: url_builder.build_url(path: "/v3/apps/#{build.package.app.guid}") },
          }
        end
      end
    end
  end
end
