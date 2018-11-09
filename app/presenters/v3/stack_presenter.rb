require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class StackPresenter < BasePresenter
    def to_hash
      {
        guid: stack.guid,
        created_at: stack.created_at,
        updated_at: stack.updated_at,
        name: stack.name,
        description: stack.description,
        links: build_links,
      }
    end

    private

    def stack
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: {
          href: url_builder.build_url(path: "/v3/stacks/#{stack.guid}")
        },
      }
    end
  end
end
