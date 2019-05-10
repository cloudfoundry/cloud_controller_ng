module VCAP::CloudController
  class IncludeSpaceOrganizationDecorator
    class << self
      def decorate(hash, spaces)
        hash[:included] ||= {}
        organization_guids = spaces.map(&:organization_guid).uniq
        organizations = Organization.where(guid: organization_guids).order(:created_at)

        hash[:included][:organizations] = organizations.map { |organization| Presenters::V3::OrganizationPresenter.new(organization).to_hash }
        hash
      end
    end
  end
end
