require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class RouteDestinationPresenter < BasePresenter
    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL
    )
      super(resource, show_secrets: show_secrets, censored_message: censored_message, decorators: [])
    end

    def to_hash
      hash = destination_hash
      hash[:links] = build_links
      hash
    end

    def destination_hash
      {
        guid: destination.guid,
        app: {
          guid: destination.app_guid,
          process: {
            type: destination.process_type
          }
        },
        weight: destination.weight,
        port: destination.presented_port,
        protocol: destination.protocol,
      }
    end

    private

    def build_links
      links = {
        destintions: {
          href: url_builder.build_url(path: "/v3/routes/#{destination.route_guid}/destinations")
        },
      }

      links[:route] = {
        href: url_builder.build_url(path: "/v3/routes/#{destination.route_guid}")
      }

      links
    end

    def destination
      @resource
    end
  end
end
