require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class SpaceQuotaSummaryPresenter < BasePresenter
        def initialize(
          resource,
          summary:,
          show_secrets: false,
          censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
          visible_space_guids: nil
        )
          super(resource, show_secrets:, censored_message:)
          @summary = summary
          @visible_space_guids = visible_space_guids
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
            self: { href: url_builder.build_url(path: "/v3/spaces/#{resource.guid}/quota_summary") },
            space: { href: url_builder.build_url(path: "/v3/spaces/#{resource.guid}") }
          }
        end
      end
    end
  end
end


