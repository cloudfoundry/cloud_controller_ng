require 'presenters/v3/base_presenter'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class RoutePresenter < BasePresenter
    def initialize(
      resource,
        show_secrets: false,
        censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL
    )
      super(resource, show_secrets: show_secrets, censored_message: censored_message)
    end

    def to_hash
      {
        guid: route.guid,
        created_at: route.created_at,
        updated_at: route.updated_at,
        host: route.host,
        relationships: {
          space: {
            data: { guid: route.space.guid }
          },
          domain: {
            data: { guid: route.domain.guid }
          }
        },
        links: build_links
      }
    end

    private

    def route
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
      links = {
        self: {
          href: url_builder.build_url(path: "/v3/routes/#{route.guid}")
        },
      }

      links[:space] = {
        href: url_builder.build_url(path: "/v3/spaces/#{route.space.guid}")
      }

      links[:domain] = {
        href: url_builder.build_url(path: "/v3/domains/#{route.domain.guid}")
      }

      links
    end
  end
end
