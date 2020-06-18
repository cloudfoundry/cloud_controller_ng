require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class OrganizationPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    class << self
      # :labels and :annotations come from MetadataPresentationHelpers
      def associated_resources
        super << :quota_definition
      end
    end

    def to_hash
      {
        guid: organization.guid,
        created_at: organization.created_at,
        updated_at: organization.updated_at,
        name: organization.name,
        suspended: organization.suspended?,
        relationships: {
          quota: {
            data: {
              guid: organization.quota_definition.guid
            }
          }
        },
        metadata: {
          labels: hashified_labels(organization.labels),
          annotations: hashified_annotations(organization.annotations)
        },
        links: build_links,
      }
    end

    private

    def organization
      @resource
    end

    def build_links
      {
        self: { href: url_builder.build_url(path: "/v3/organizations/#{organization.guid}") },
        domains: { href: url_builder.build_url(path: "/v3/organizations/#{organization.guid}/domains") },
        default_domain: { href: url_builder.build_url(path: "/v3/organizations/#{organization.guid}/domains/default") },
        quota: { href: url_builder.build_url(path: "/v3/organization_quotas/#{organization.quota_definition.guid}") }
      }
    end
  end
end
