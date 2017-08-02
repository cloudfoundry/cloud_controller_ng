module VCAP::CloudController::Presenters::V3
  class OrganizationPresenter < BasePresenter
    def to_hash
      {
        guid: organization.guid,
        created_at: organization.created_at,
        updated_at: organization.updated_at,
        name: organization.name,
        links: build_links,
      }
    end

    private

    def organization
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: { href: url_builder.build_url(path: "/v3/organizations/#{organization.guid}") },
      }
    end
  end
end
