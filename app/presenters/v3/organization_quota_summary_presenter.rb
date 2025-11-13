require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class OrganizationQuotaSummaryPresenter < BasePresenter
        def initialize(
          resource,
          summary:,
          show_secrets: false,
          censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
          visible_org_guids: nil
        )
          super(resource, show_secrets:, censored_message:)
          @summary = summary
          @visible_org_guids = visible_org_guids
        end

        def to_hash
          {
            quota_summary: @summary,
            links: build_links
          }
        end

        private

        def resource
          @resource
        end

        def build_links
          {
            self: { href: url_builder.build_url(path: "/v3/organizations/#{resource.guid}/quota_summary") },
            organization: { href: url_builder.build_url(path: "/v3/organizations/#{resource.guid}") }
          }
        end
      end
    end
  end
end
