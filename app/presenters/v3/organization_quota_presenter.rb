require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/quota_presenter_builder'

module VCAP::CloudController::Presenters::V3
  class OrganizationQuotaPresenter < BasePresenter
    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
      all_orgs_visible: false,
      visible_org_guids_query: nil
    )
      super(resource, show_secrets:, censored_message:)
      @all_orgs_visible = all_orgs_visible
      @visible_org_guids_query = visible_org_guids_query
    end

    def to_hash
      builder = VCAP::CloudController::Presenters::QuotaPresenterBuilder.new(quota)
      builder.add_resource_limits.
        add_domains.
        add_relationships(relationships).
        add_links(build_links)
      builder.build
    end

    private

    def quota
      @resource
    end

    def relationships
      {
        organizations: {
          data: filtered_visible_orgs
        }
      }
    end

    def filtered_visible_orgs
      ds = quota.organizations_dataset
      ds = ds.where(guid: @visible_org_guids_query) unless @all_orgs_visible
      ds.select_map(:guid).map { |g| { guid: g } }
    end

    def build_links
      {
        self: { href: url_builder.build_url(path: "/v3/organization_quotas/#{quota.guid}") }
      }
    end

    def unlimited_to_nil(value)
      value == -1 ? nil : value
    end
  end
end
