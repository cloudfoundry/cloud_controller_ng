require 'presenters/v3/base_presenter'
require 'presenters/v3/route_destination_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class RoutePresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    class << self
      # :labels and :annotations come from MetadataPresentationHelpers
      def associated_resources
        [:domain, :space, :route_mappings].concat(super)
      end
    end

    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
      decorators: []
    )
      super(resource, show_secrets: show_secrets, censored_message: censored_message, decorators: decorators)
    end

    def to_hash
      hash = {
        guid: route.guid,
        created_at: route.created_at,
        updated_at: route.updated_at,
        protocol: route.domain.protocols[0],
        host: route.host,
        path: route.path,
        port: route.port,
        url: build_url,
        destinations: route.route_mappings.map { |rm| RouteDestinationPresenter.new(rm).to_hash },
        metadata: {
          labels: hashified_labels(route.labels),
          annotations: hashified_annotations(route.annotations),
        },
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

      @decorators.reduce(hash) { |memo, d| d.decorate(memo, [route]) }
    end

    private

    def route
      @resource
    end

    def build_links
      links = {
        self: {
          href: url_builder.build_url(path: "/v3/routes/#{route.guid}")
        },
      }

      links[:space] = {
        href: url_builder.build_url(path: "/v3/spaces/#{route.space.guid}")
      }

      links[:destinations] = {
        href: url_builder.build_url(path: "/v3/routes/#{route.guid}/destinations")
      }

      links[:domain] = {
        href: url_builder.build_url(path: "/v3/domains/#{route.domain.guid}")
      }

      links
    end

    def build_url
      if route.port && route.port > 0
        return "#{route.domain.name}:#{route.port}"
      end

      if route.host.empty?
        return "#{route.domain.name}#{route.path}"
      end

      "#{route.host}.#{route.domain.name}#{route.path}"
    end
  end
end
