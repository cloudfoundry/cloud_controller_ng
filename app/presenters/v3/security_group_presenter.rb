require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class SecurityGroupPresenter < BasePresenter
    def to_hash
      {
        guid: security_group.guid,
        created_at: security_group.created_at,
        updated_at: security_group.updated_at,
        name: security_group.name,
        globally_enabled: {
          running: security_group.running_default,
          staging: security_group.staging_default,
        },
        links: build_links,
      }
    end

    private

    def security_group
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: { href: url_builder.build_url(path: "/v3/security_groups/#{security_group.guid}") },
      }
    end
  end
end
