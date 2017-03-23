require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class BuildPresenter < BasePresenter
        def to_hash
          {
            guid: build.guid,
            state: build.state,
            error: nil,
            lifecycle: {
              type: droplet.lifecycle_type,
              data: droplet.lifecycle_data.to_hash
            },
            droplet: { guid: droplet.guid },
            created_at: build.created_at,
            updated_at: build.updated_at,
            package: { guid: package.guid },
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
