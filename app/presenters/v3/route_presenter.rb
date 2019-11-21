require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/helpers/censorship'

module VCAP::CloudController::Presenters::V3
  class RoutePresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    class << self
      # :labels and :annotations come from MetadataPresentationHelpers
      def associated_resources
        [:domain, :space].concat(super)
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
        host: route.host,
        path: route.path,
        url: build_url,
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
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
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
      if route.host.empty?
        return "#{route.domain.name}#{route.path}"
      end

      "#{route.host}.#{route.domain.name}#{route.path}"
    end
  end
end
