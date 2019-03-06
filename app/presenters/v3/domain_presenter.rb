require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class DomainPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    def to_hash
      {
        guid: domain.guid,
        created_at: domain.created_at,
        updated_at: domain.updated_at,
        name: domain.name,
        internal: domain.internal,
        links: build_links,
      }
    end

    private

    def domain
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: {
          href: url_builder.build_url(path: "/v3/domains/#{domain.guid}")
        },
      }
    end
  end
end
