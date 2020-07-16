require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class DomainPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers
    def initialize(
      resource,
        show_secrets: false,
        censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
        visible_org_guids: []
    )
      @visible_org_guids = visible_org_guids

      super(resource, show_secrets: show_secrets, censored_message: censored_message)
    end

    def to_hash
      {
        guid: domain.guid,
        created_at: domain.created_at,
        updated_at: domain.updated_at,
        name: domain.name,
        internal: domain.internal,
        router_group: hashified_router_group(domain.router_group_guid),
        supported_protocols: domain.protocols,
        relationships: {
          organization: {
            data: owning_org_guid
          },
          shared_organizations: {
            data: shared_org_guids
          }
        },
        metadata: {
          labels: hashified_labels(domain.labels),
          annotations: hashified_annotations(domain.annotations),
        },
        links: build_links
      }
    end

    private

    attr_reader :visible_org_guids

    def shared_org_guids
      org_guids = domain.shared_organizations.map(&:guid)
      org_guids &= visible_org_guids
      org_guids.map { |org_guid| { guid: org_guid } }
    end

    def owning_org_guid
      domain.owning_organization ? { guid: domain.owning_organization.guid } : nil
    end

    def domain
      @resource
    end

    def hashified_router_group(router_group_guid)
      router_group_guid ? { guid: router_group_guid } : nil
    end

    def build_links
      links = {
        self: {
          href: url_builder.build_url(path: "/v3/domains/#{domain.guid}")
        },
        route_reservations: {
          href: url_builder.build_url(path: "/v3/domains/#{domain.guid}/route_reservations")
        }
      }

      if domain.owning_organization
        links[:organization] = {
          href: url_builder.build_url(path: "/v3/organizations/#{domain.owning_organization.guid}")
        }
        links[:shared_organizations] = {
          href: url_builder.build_url(path: "/v3/domains/#{domain.guid}/relationships/shared_organizations")
        }
      end

      if domain.router_group_guid && domain.routing_api_client.enabled?
        links[:router_group] = {
          href: url_builder.build_url(path: "/routing/v1/router_groups/#{domain.router_group_guid}")
        }
      end

      links
    end
  end
end
