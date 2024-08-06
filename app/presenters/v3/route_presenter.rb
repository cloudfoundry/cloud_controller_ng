require 'presenters/v3/base_presenter'
require 'presenters/v3/route_destinations_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class RoutePresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    class << self
      # :labels and :annotations come from MetadataPresentationHelpers
      def associated_resources
        %i[domain space route_mappings].concat(super)
      end
    end

    def initialize(
      resource,
      show_secrets: false,
      censored_message: VCAP::CloudController::Presenters::Censorship::REDACTED_CREDENTIAL,
      decorators: []
    )
      super
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
        destinations: RouteDestinationsPresenter.new(route.route_mappings, route:).presented_destinations,
        metadata: {
          labels: hashified_labels(route.labels),
          annotations: hashified_annotations(route.annotations)
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
        }
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
      return "#{route.domain.name}:#{route.port}" if route.port && route.port > 0

      return "#{route.domain.name}#{route.path}" if route.host.empty?

      "#{route.host}.#{route.domain.name}#{route.path}"
    end
  end
end
