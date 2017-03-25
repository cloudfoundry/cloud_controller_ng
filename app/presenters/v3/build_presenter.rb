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
            error: droplet.error,
            lifecycle: {
              type: droplet.lifecycle_type,
              data: droplet.lifecycle_data.to_hash
            },
            package: { guid: package.guid },
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
          if droplet.state == VCAP::CloudController::DropletModel::STAGED_STATE
            return { guid: droplet.guid }
          end
          nil
        end

        def package
          droplet.package
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
          {
            self: { href: url_builder.build_url(path: "/v3/builds/#{build.guid}") },
            app: { href: url_builder.build_url(path: "/v3/apps/#{package.app.guid}") },
          }
        end
      end
    end
  end
end
