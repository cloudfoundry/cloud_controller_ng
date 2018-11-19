module VCAP::CloudController
  module Presenters
    module V3
      class RevisionPresenter < BasePresenter
        def to_hash
          {
            guid: revision.guid,
            version: revision.version,
            created_at: revision.created_at,
            updated_at: revision.updated_at,
            links: build_links
          }
        end

        private

        def revision
          @resource
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          {
            self: {
              href: url_builder.build_url(path: "/v3/apps/#{revision.app_guid}/revisions/#{revision.guid}")
            }
          }
        end
      end
    end
  end
end
