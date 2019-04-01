require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class DomainPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    def to_hash
      if domain.shared?
        to_base_hash
      else
        to_base_hash.merge(org_relationship)
      end
    end

    private

    def to_base_hash
      {
        guid: domain.guid,
        created_at: domain.created_at,
        updated_at: domain.updated_at,
        name: domain.name,
        internal: domain.internal,
        links: build_links,
      }
    end

    def org_relationship
      {
        relationships: {
          organization: {
            data: {
              guid: domain.owning_organization.guid
            },
          },
        },
      }
    end

    def domain
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: {
          href: url_builder.build_url(path: "/v3/domains/#{domain.guid}")
        },
      }
    end
  end
end
