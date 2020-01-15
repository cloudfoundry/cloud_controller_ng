require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class SpaceQuotaPresenter < BasePresenter
    def to_hash
      {
        guid: space_quota.guid,
        created_at: space_quota.created_at,
        updated_at: space_quota.updated_at,
        name: space_quota.name,
        relationships: {
          organization: {
            data: { guid: space_quota.organization.guid }
          }
        },
        links: build_links,
      }
    end

    private

    def space_quota
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: { href: url_builder.build_url(path: "/v3/space_quotas/#{space_quota.guid}") },
        organization: { href: url_builder.build_url(path: "/v3/organizations/#{space_quota.organization.guid}") },
      }
    end
  end
end
