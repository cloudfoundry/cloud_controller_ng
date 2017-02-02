module VCAP::CloudController::Presenters::V3
  class OrganizationPresenter < BasePresenter
    def to_hash
      {
        guid: organization.guid,
        created_at: organization.created_at,
        updated_at: organization.updated_at,
        name: organization.name,
        links: {}
      }
    end

    private

    def organization
      @resource
    end
  end
end
