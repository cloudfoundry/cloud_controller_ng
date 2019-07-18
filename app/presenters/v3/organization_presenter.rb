require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class OrganizationPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    class << self
      def associated_resources
        [
          :quota_definition,
          :labels,
          :annotations
        ]
      end
    end

    def to_hash
      {
        guid: organization.guid,
        created_at: organization.created_at,
        updated_at: organization.updated_at,
        name: organization.name,
        status: organization.status,
        relationships: {
          quota: {
            data: {
              guid: organization.quota_definition.guid
            }
          }
        },
        links: build_links,
        metadata: {
          labels: hashified_labels(organization.labels),
          annotations: hashified_annotations(organization.annotations)
        }
      }
    end

    private

    def organization
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: { href: url_builder.build_url(path: "/v3/organizations/#{organization.guid}") },
        domains: { href: url_builder.build_url(path: "/v3/organizations/#{organization.guid}/domains") },
        default_domain: { href: url_builder.build_url(path: "/v3/organizations/#{organization.guid}/domains/default") }
      }
    end
  end
end
