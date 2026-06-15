require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/quota_presenter_builder'

module VCAP::CloudController::Presenters::V3
  class SpaceQuotaPresenter < BasePresenter
    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
      all_spaces_visible: false,
      visible_space_guids: []
    )
      super(resource, show_secrets:, censored_message:)
      @visible_space_guids = visible_space_guids
      @all_spaces_visible = all_spaces_visible
    end

    def to_hash
      builder = VCAP::CloudController::Presenters::QuotaPresenterBuilder.new(quota)
      builder.add_resource_limits.
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
        organization: {
          data: { guid: quota.organization.guid }
        },
        spaces: {
          data: filtered_visible_spaces
        }
      }
    end

    def filtered_visible_spaces
      visible_spaces = if @all_spaces_visible
                         quota.spaces
                       else
                         quota.spaces.select { |space| @visible_space_guids.include? space.guid }
                       end
      visible_spaces.map { |space| { guid: space.guid } }
    end

    def build_links
      {
        self: { href: url_builder.build_url(path: "/v3/space_quotas/#{quota.guid}") },
        organization: { href: url_builder.build_url(path: "/v3/organizations/#{quota.organization.guid}") }
      }
    end
  end
end
