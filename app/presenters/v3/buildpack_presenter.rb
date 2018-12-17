require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class BuildpackPresenter < BasePresenter
    def to_hash
      {
        guid: buildpack.guid,
        created_at: buildpack.created_at,
        updated_at: buildpack.updated_at,
        name: buildpack.name,
        stack: buildpack.stack,
        state: 'AWAITING_UPLOAD',
        position: buildpack.position,
        enabled: buildpack.enabled,
        locked: buildpack.locked,
        links: build_links,
      }
    end

    private

    def buildpack
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: {
          href: url_builder.build_url(path: "/v3/buildpacks/#{buildpack.guid}")
        },
      }
    end
  end
end
