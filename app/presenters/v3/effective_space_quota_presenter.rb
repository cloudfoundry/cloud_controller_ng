require 'presenters/v3/base_presenter'
require 'presenters/helpers/quota_presenter_builder'

module VCAP::CloudController::Presenters::V3
  class EffectiveSpaceQuotaPresenter < BasePresenter
    def initialize(effective_space_quota, space)
      super(effective_space_quota)
      @space = space
    end

    def to_hash
      builder = VCAP::CloudController::Presenters::QuotaPresenterBuilder.new(effective_space_quota)
      builder.add_resource_limits
      builder.add_links(build_links)
      builder.build
    end

    private

    def build_links
      {
        self: { href: url_builder.build_url(path: "/v3/spaces/#{@space.guid}/effective_quota") },
        usage_summary: { href: url_builder.build_url(path: "/v3/spaces/#{@space.guid}/usage_summary") },
        space: { href: url_builder.build_url(path: "/v3/spaces/#{@space.guid}") }
      }
    end

    def effective_space_quota
      @resource
    end
  end
end
